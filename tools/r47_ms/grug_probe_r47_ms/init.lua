-- Disposable engine probe (Round 47 lane OR: the migration step 0.47.0 end
-- to end). Never shipped: tools/r47_ms/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.45.1 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   each join   first of all join callbacks (before grug_core's migration
--               runner): the tool facts as loaded and the marker; in a
--               "setup" phase the character is then built (below); 2.5 s
--               after the join the tool facts as the game left them;
--   then        once every character the plan names has left again, it
--               writes the file and shuts the server down.
-- The facts of a tool stack: whether it carries a stored copy
-- (`tool_capabilities`, `_grug_repair_caps`), the cracky maxlevel of the
-- capabilities it digs with (a broken one: of the copy kept for the
-- repair), whether those equal what a craft of the same tool (broken the
-- same way) gets now, and three digs through core.get_dig_params.
-- The setup (0.45.1), every stack made as the game makes it (crafted:
-- grug_items.crafted_output; broken: worn out before the craft rebuild):
--   miner    crafted Iron, Bronze and Wood picks and a Steel Axe on the
--            hotbar and in main, a broken crafted Iron pick, a plain Stone
--            pick without a copy, a crafted Iron Sword, a crafted Iron pick
--            in a bag and a crafted Bronze pick in the crafting output area;
--   sleeper  a crafted Iron pick; joins only for the setup.

local P = "[r47_ms_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version
local MARKER = "grug_core:migrate:0.47.0"

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

local function equal(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do
		if not equal(value, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

local BROKEN = 65535

-- What a craft of this tool gets now (broken the same way when `broken`).
local function fresh(name, broken, player)
	local stack = ItemStack(name)
	if broken then stack:set_wear(BROKEN) end
	grug_items.crafted_output(stack, player)
	return stack
end

local function digging_caps(stack)
	if stack:get_wear() >= BROKEN then
		return core.deserialize(stack:get_meta():get_string("_grug_repair_caps"))
	end
	return stack:get_tool_capabilities()
end

local function dig(node, caps)
	local def = core.registered_nodes[node]
	local params = def and caps and core.get_dig_params(def.groups, caps)
	return params and params.diggable and params.time or false
end

local function facts(stack, player)
	if stack:is_empty() then return nil end
	local meta = stack:get_meta()
	local caps = digging_caps(stack)
	local now = fresh(stack:get_name(), stack:get_wear() >= BROKEN, player)
	local cracky = type(caps) == "table" and caps.groupcaps and caps.groupcaps.cracky
	-- A broken stack's copy is a plain copy of the definition's table
	-- (grug_quality apply_capabilities); a usable one reads as the engine
	-- reads the definition for a stack without meta.
	local definition
	if stack:get_wear() >= BROKEN then
		definition = equal(caps, stack:get_definition().tool_capabilities)
	else
		definition = equal(caps, ItemStack(stack:get_name()):get_tool_capabilities())
	end
	return {
		item = stack:get_name(),
		wear = stack:get_wear(),
		stored = meta:get_string("tool_capabilities") ~= "",
		kept = meta:get_string("_grug_repair_caps") ~= "",
		caps_text = meta:get_string("tool_capabilities"),
		maxlevel = cracky and cracky.maxlevel or false,
		as_crafted_now = equal(caps, digging_caps(now)),
		definition = definition,
		dig = {t2_stone = dig("grug_materials:t2_stone", caps),
			iron_ore = dig("default:stone_with_iron", caps),
			stone = dig("default:stone", caps)},
	}
end

local function tools(player)
	local out = {}
	for listname, list in pairs(player:get_inventory():get_lists()) do
		for index, stack in ipairs(list) do
			local item = not stack:is_empty() and stack:get_name()
			if item and (core.get_item_group(item, "grug_gathering_tool") > 0 or
					core.get_item_group(item, "grug_equip_weapon") > 0) then
				out[listname .. "[" .. index .. "]"] = facts(stack, player)
			end
		end
	end
	return out
end

local function state(player)
	return {tools = tools(player), marker = player:get_meta():get_string(MARKER)}
end

-- The 0.45.1 build.
local function crafted(player, name, broken)
	local stack = ItemStack(name)
	assert(core.registered_items[name], P .. "not registered: " .. name)
	if broken then stack:set_wear(BROKEN) end
	assert(grug_items.crafted_output(stack, player), P .. "crafted_output " .. name)
	return stack
end

local function clear(player)
	local inv = player:get_inventory()
	for name in pairs(inv:get_lists()) do inv:set_list(name, {}) end
	return inv
end

local function build_miner(player)
	local inv = clear(player)
	inv:set_stack("main", 1, crafted(player, "grug_materials:pick_iron"))
	inv:set_stack("main", 2, crafted(player, "grug_materials:pick_bronze"))
	inv:set_stack("main", 3, crafted(player, "grug_materials:pick_wood"))
	inv:set_stack("main", 10, crafted(player, "grug_materials:axe_steel"))
	inv:set_stack("main", 11, crafted(player, "grug_materials:pick_iron", true))
	inv:set_stack("main", 12, ItemStack("grug_materials:pick_stone"))
	inv:set_stack("main", 13, crafted(player, "grug_gear:sword_iron"))
	inv:set_stack(grug_inventory.bag_list(1), 1, "grug_inventory:bag_small")
	local bag = grug_inventory.content_list(1)
	inv:set_size(bag, 8)
	inv:set_stack(bag, 2, crafted(player, "grug_materials:pick_iron"))
	grug_jobs.ensure_output_area(player)
	inv:set_stack("grug_craft_out", 1, crafted(player, "grug_materials:pick_bronze"))
	return true
end

local function build_sleeper(player)
	clear(player)
	player:get_inventory():set_stack("main", 1, crafted(player, "grug_materials:pick_iron"))
	return true
end

local BUILD = {miner = build_miner, sleeper = build_sleeper}

local function on_join(player)
	local name = player:get_player_name()
	local entry = {name = name, loaded = state(player)}
	obs.joins[#obs.joins + 1] = entry
	log("joined " .. name)
	if setup and BUILD[name] then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, err = pcall(BUILD[name], current)
			entry.built_ok = ok
			entry.build_error = not ok and tostring(err) or nil
			log("built " .. name .. (ok and "" or (": " .. tostring(err))))
		end)
	end
	core.after(2.5, function()
		local current = core.get_player_by_name(name)
		if current then entry.settled = state(current) end
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
	core.after(0.5, function() core.request_shutdown("r47 ms probe done") end)
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
	core.after(150, finish, "timeout: not every planned character joined and left")
end)
