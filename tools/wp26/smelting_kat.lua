-- WP26 -- the smelting surface, headless.
--
-- What this proves, on the REAL shipped bytes of `mods/ITEMS/grug_smelting`
-- and `mods/ENTITIES/grug_traders/audit_alloys.lua` loaded against a stub
-- engine:
--
--   1. RECIPE-SURFACE EXACTNESS (task card gate 1). The five cooking recipes,
--      the five `dualfurn` alloys, the twelve storage pack/unpack pairs and the
--      one station recipe registered by the mod are exactly the ones
--      `items_crafting.md` §3.0.1/§3.0.2 and the card's §3.2-§3.5 name --
--      no extra output, none missing. The expectation is spelled out here
--      independently of the mod's own tables, which is the whole point: a
--      loop that registers itself cannot prove what it should have registered.
--   2. THE CHAIN IS REACHABLE. Starting from only mined items, forward
--      closure over the cooking and alloy families reaches all six tier bars
--      up to Abyssal Steel, and the derivation depth of each is reported.
--   3. EVERY INPUT EXISTS. Every itemstring the mod names is registered by
--      `grug_materials` or `default` -- checked against the registrations
--      those mods actually make, not a hand-copied list.
--   4. NO REGIONAL, CULTURAL OR TROPHY INPUT (§3.0.2 last line, gate 5).
--   5. STORAGE ROUND-TRIPS. All twelve `PROCESSED_MATERIALS` rows pack 9 -> 1
--      and unpack 1 -> 9, both directions, same item, and `emberglass_shard`
--      and every gem stay out of the family.
--   6. THE MATCHER AND THE NODE TIMER, behaviourally, against the shipped
--      `node.lua`: either slot order alloys, exactly one of each input is
--      consumed per output, and Iron Bar with Coal in the FUEL slot cooks
--      nothing while Coal in a MATERIAL slot makes Steel (gates 2 and 3).
--   7. THE §3.5 AUDIT EXTENSION, including its negative test: a deliberately
--      overpriced synthetic `dualfurn` recipe is caught by the very function
--      `grug_traders` calls, and the shipped recipes are not.
--
-- What it does NOT prove, on purpose: that the engine's own craft system
-- answers these registrations (that is `grug_smelting`'s startup self-audit,
-- which needs a real `core.get_craft_result` and runs on every server start),
-- and that a furnace placed in a world actually smelts (that is
-- `tools/wp26/smelt_probe`).
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.
--
--     luajit          -e 'io.write(dofile("tools/wp26/smelting_kat.lua")("."))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp26/smelting_kat.lua")("."))'

return function(repo)
	local report = {}
	local function say(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[index] = tostring((select(index, ...)))
		end
		report[#report + 1] = table.concat(parts, "\t") .. "\n"
	end
	local function fail(message)
		error("wp26 smelting: " .. message, 0)
	end
	local function want(condition, message)
		if not condition then
			fail(message)
		end
	end

	-- ------------------------------------------------------------------
	-- 0. What the card says the surface is. Written out here, not read
	--    from the mod.
	-- ------------------------------------------------------------------
	local EXPECTED_SMELTS = {
		{"grug_materials:copper_bar", "default:copper_lump"},
		{"grug_materials:tin_bar", "default:tin_lump"},
		{"grug_materials:iron_bar", "default:iron_lump"},
		{"grug_materials:silver_bar", "grug_materials:silver_lump"},
		{"grug_materials:gold_bar", "default:gold_lump"},
	}
	local EXPECTED_ALLOYS = {
		{"grug_materials:bronze_bar",
			"grug_materials:copper_bar", "grug_materials:tin_bar"},
		{"grug_materials:steel_bar",
			"grug_materials:iron_bar", "default:coal_lump"},
		{"grug_materials:silversteel_bar",
			"grug_materials:steel_bar", "grug_materials:silver_bar"},
		{"grug_materials:embersteel_bar",
			"grug_materials:silversteel_bar", "grug_materials:emberglass"},
		{"grug_materials:abyssal_steel_bar",
			"grug_materials:embersteel_bar", "grug_materials:abyssal_crystal"},
	}
	-- The six tier bars of §3.0.1, in ladder order.
	local LADDER = {"grug_materials:bronze_bar", "grug_materials:iron_bar",
		"grug_materials:steel_bar", "grug_materials:silversteel_bar",
		"grug_materials:embersteel_bar", "grug_materials:abyssal_steel_bar"}
	-- Items that must NEVER gain a recipe from this mod.
	local NEVER = {"grug_materials:emberglass_shard",
		"grug_materials:cut_citrine", "grug_materials:rough_citrine",
		"grug_materials:citrine_block", "grug_materials:cut_diamond",
		"grug_materials:diamond_block", "grug_materials:sunwax",
		"grug_materials:gravesalt"}

	-- ==================================================================
	-- 1. A stub engine, and the real mods loaded into it
	-- ==================================================================
	local stub = {}
	local registered = {}      -- itemstring -> its registered kind
	local crafts = {}          -- recorded core.register_craft calls
	local mods_loaded = {}     -- captured callbacks, deliberately never run
	local nodes = {}           -- itemstring -> node definition

	-- --- ItemStack ---------------------------------------------------
	local Stack = {}
	Stack.__index = Stack
	local function new_stack(spec)
		if type(spec) == "table" then
			return setmetatable({name = spec.name, count = spec.count}, Stack)
		end
		spec = tostring(spec or "")
		local name, count = spec:match("^(%S+)%s+(%d+)$")
		if not name then
			name, count = spec, (spec == "" and 0 or 1)
		end
		return setmetatable({name = name, count = tonumber(count)}, Stack)
	end
	function Stack:get_name() return self.count > 0 and self.name or "" end
	function Stack:get_count() return self.count end
	function Stack:is_empty() return self.count <= 0 end
	function Stack:to_string()
		if self.count <= 0 then return "" end
		return self.name .. " " .. self.count
	end
	function Stack:take_item(n)
		n = n or 1
		local taken = math.min(n, self.count)
		self.count = self.count - taken
		if self.count <= 0 then
			self.name, self.count = "", 0
		end
		return new_stack(self.name .. " " .. taken)
	end

	-- --- inventory ---------------------------------------------------
	local Inv = {}
	Inv.__index = Inv
	local function new_inv()
		return setmetatable({lists = {}}, Inv)
	end
	function Inv:set_size(listname, size)
		local list = {}
		for index = 1, size do list[index] = new_stack("") end
		self.lists[listname] = list
	end
	function Inv:get_stack(listname, index)
		local stack = self.lists[listname][index]
		return new_stack({name = stack.name, count = stack.count})
	end
	function Inv:set_stack(listname, index, stack)
		stack = type(stack) == "table" and stack or new_stack(stack)
		self.lists[listname][index] =
			new_stack({name = stack.name, count = stack.count})
	end
	function Inv:get_list(listname)
		local out = {}
		for index, stack in ipairs(self.lists[listname]) do
			out[index] = new_stack({name = stack.name, count = stack.count})
		end
		return out
	end
	function Inv:is_empty(listname)
		for _, stack in ipairs(self.lists[listname]) do
			if stack.count > 0 then return false end
		end
		return true
	end
	function Inv:room_for_item(listname, item)
		local wanted = new_stack(item)
		for _, stack in ipairs(self.lists[listname]) do
			if stack.count <= 0 or
					(stack.name == wanted.name and stack.count < 99) then
				return true
			end
		end
		return false
	end
	function Inv:add_item(listname, item)
		local wanted = new_stack(item)
		for _, stack in ipairs(self.lists[listname]) do
			if stack.name == wanted.name and stack.count > 0 and
					stack.count < 99 then
				stack.count = stack.count + wanted.count
				return new_stack("")
			end
		end
		for _, stack in ipairs(self.lists[listname]) do
			if stack.count <= 0 then
				stack.name, stack.count = wanted.name, wanted.count
				return new_stack("")
			end
		end
		return wanted
	end

	-- --- node meta ---------------------------------------------------
	local metas = {}
	local function meta_for(pos)
		local key = pos.x .. "," .. pos.y .. "," .. pos.z
		if not metas[key] then
			local store = {floats = {}, strings = {}, inv = new_inv()}
			metas[key] = {
				get_float = function(_, k) return store.floats[k] or 0 end,
				set_float = function(_, k, v) store.floats[k] = v end,
				get_string = function(_, k) return store.strings[k] or "" end,
				set_string = function(_, k, v) store.strings[k] = v end,
				get_inventory = function() return store.inv end,
				_store = store,
			}
		end
		return metas[key]
	end

	-- --- the engine surface the two mods touch at load time ----------
	local placed = {}
	local timers = {}
	local FUEL_TIME = {["default:coal_lump"] = 40, ["default:tree"] = 30}

	function stub.get_modpath(name)
		if name == "grug_smelting" then
			return repo .. "/mods/ITEMS/grug_smelting"
		elseif name == "grug_traders" then
			return repo .. "/mods/ENTITIES/grug_traders"
		end
		return nil
	end
	local current_mod = "grug_smelting"
	function stub.get_current_modname() return current_mod end
	function stub.register_node(name, def)
		registered[name] = "node"
		nodes[name] = def
	end
	function stub.register_craftitem(name) registered[name] = "craftitem" end
	function stub.register_tool(name) registered[name] = "tool" end
	function stub.register_craft(def) crafts[#crafts + 1] = def end
	function stub.register_on_mods_loaded(fn)
		mods_loaded[#mods_loaded + 1] = fn
	end
	function stub.log() end
	function stub.get_node(pos)
		local key = pos.x .. "," .. pos.y .. "," .. pos.z
		return placed[key] or {name = "air", param2 = 0}
	end
	function stub.swap_node(pos, node)
		placed[pos.x .. "," .. pos.y .. "," .. pos.z] = node
	end
	function stub.get_node_timer(pos)
		local key = pos.x .. "," .. pos.y .. "," .. pos.z
		timers[key] = timers[key] or {running = false}
		local timer = timers[key]
		return {
			start = function(_, t) timer.running, timer.interval = true, t end,
			stop = function() timer.running = false end,
		}
	end
	function stub.get_craft_result(input)
		if input.method == "fuel" then
			local first = input.items and input.items[1]
			local name = first and (type(first) == "table" and first:get_name()
				or tostring(first)) or ""
			local burn = FUEL_TIME[name] or 0
			local after = new_stack(name)
			if burn > 0 then after:take_item(1) end
			return {time = burn, replacements = {}, item = new_stack("")},
				{items = {after}}
		end
		return {time = 0, item = new_stack(""), replacements = {}},
			{items = {new_stack("")}}
	end
	function stub.is_protected() return false end
	function stub.find_node_near() return nil end
	function stub.item_drop() end
	stub.registered_items = registered
	stub.registered_nodes = nodes
	stub.get_meta = meta_for
	setmetatable(stub, {__index = function(t, key)
		local noop = function() end
		rawset(t, key, noop)
		return noop
	end})

	-- Globals the two mods publish or read, saved and restored.
	local saved, had = {}, {}
	local function set_global(name, value)
		had[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
		rawset(_G, name, value)
	end
	local function restore_globals()
		for name in pairs(saved) do
			if had[name] then
				rawset(_G, name, saved[name])
			else
				rawset(_G, name, nil)
			end
		end
	end

	local sound_stub = setmetatable({}, {__index = function() return {} end})
	set_global("core", stub)
	set_global("minetest", stub)
	set_global("ItemStack", new_stack)
	set_global("vector", {
		offset = function(p, x, y, z)
			return {x = p.x + x, y = p.y + y, z = p.z + z}
		end,
	})
	-- Anything `default` is asked for beyond this list is a registration
	-- helper (`register_mesepost`, …); an inert function is the honest
	-- answer, exactly as for `core`.
	set_global("default", setmetatable({
		get_hotbar_bg = function() return "" end,
		node_sound_stone_defaults = function() return sound_stub end,
		node_sound_metal_defaults = function() return sound_stub end,
		node_sound_glass_defaults = function() return sound_stub end,
		node_sound_wood_defaults = function() return sound_stub end,
		node_sound_leaves_defaults = function() return sound_stub end,
		node_sound_dirt_defaults = function() return sound_stub end,
		node_sound_sand_defaults = function() return sound_stub end,
		node_sound_gravel_defaults = function() return sound_stub end,
		node_sound_water_defaults = function() return sound_stub end,
		set_inventory_action_loggers = function() end,
		get_translator = function() return function(s) return s end end,
		LIGHT_MAX = 14,
	}, {__index = function(t, key)
		local noop = function() end
		rawset(t, key, noop)
		return noop
	end}))
	set_global("grug_materials", {})
	set_global("grug_smelting", nil)
	set_global("grug_traders", nil)

	local ok, err = pcall(function()
		-- `grug_materials` first: the canonical registry and the concrete
		-- items. `registry.lua` is pure data plus its own validation;
		-- `ores.lua` is what actually registers the bars, lumps, gems,
		-- cultural materials and storage blocks this KAT checks against.
		current_mod = "grug_materials"
		dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
		-- `mining.lua` only for `resource_ore_description`, which `ores.lua`
		-- calls while registering; it installs a `core.node_dig` wrapper that
		-- the stub swallows and nothing here ever calls.
		dofile(repo .. "/mods/ITEMS/grug_materials/mining.lua")
		dofile(repo .. "/mods/ITEMS/grug_materials/ores.lua")
		-- The five vendored lumps `default` owns and WP43 keeps.
		for _, name in ipairs({"default:copper_lump", "default:tin_lump",
				"default:iron_lump", "default:gold_lump", "default:coal_lump",
				"default:furnace"}) do
			registered[name] = registered[name] or "craftitem"
		end
		-- The mod's own entry point, so the KAT runs the real load order.
		current_mod = "grug_smelting"
		dofile(repo .. "/mods/ITEMS/grug_smelting/init.lua")
	end)
	if not ok then
		restore_globals()
		error(err, 0)
	end

	local materials = rawget(_G, "grug_materials")
	local smelting = rawget(_G, "grug_smelting")

	-- The rest of the KAT runs with the stub globals still installed,
	-- because the node timer under test reads them. Everything is restored
	-- before the report is returned.
	local checked, failure = pcall(function()

	-- ==================================================================
	-- 2. Recipe-surface exactness (gate 1)
	-- ==================================================================
	local cooking, packs, unpacks, station = {}, {}, {}, {}
	local other = {}
	for _, def in ipairs(crafts) do
		if def.type == "cooking" then
			cooking[#cooking + 1] = {def.output, def.recipe, def.cooktime}
		elseif def.output == smelting.NODE then
			station[#station + 1] = def
		elseif type(def.recipe) == "table" and #def.recipe == 3 and
				type(def.recipe[1]) == "table" and #def.recipe[1] == 3 then
			packs[def.output] = def.recipe[1][1]
		elseif type(def.recipe) == "table" and #def.recipe == 1 and
				type(def.recipe[1]) == "table" and #def.recipe[1] == 1 then
			unpacks[def.output] = def.recipe[1][1]
		else
			other[#other + 1] = tostring(def.output)
		end
	end
	want(#other == 0, "unclassified recipe(s): " .. table.concat(other, ", "))

	want(#cooking == #EXPECTED_SMELTS, #cooking ..
		" cooking recipes, not " .. #EXPECTED_SMELTS)
	for index, expected in ipairs(EXPECTED_SMELTS) do
		local got = cooking[index]
		want(got[1] == expected[1] and got[2] == expected[2],
			"cooking recipe " .. index .. " is " .. tostring(got[1]) ..
			" from " .. tostring(got[2]) .. ", not " .. expected[1] ..
			" from " .. expected[2])
		want(type(got[3]) == "number" and got[3] > 0,
			"cooking recipe " .. expected[1] .. " has no positive cooktime")
		say("wp26_cook", expected[1], expected[2], got[3])
	end

	want(#smelting.RECIPES == #EXPECTED_ALLOYS, #smelting.RECIPES ..
		" dualfurn recipes, not " .. #EXPECTED_ALLOYS)
	for index, expected in ipairs(EXPECTED_ALLOYS) do
		local recipe = smelting.RECIPES[index]
		want(recipe.output == expected[1], "alloy " .. index ..
			" outputs " .. recipe.output .. ", not " .. expected[1])
		want(#recipe.inputs == 2, expected[1] .. " has " .. #recipe.inputs ..
			" inputs, not two")
		want(recipe.inputs[1] == expected[2] and recipe.inputs[2] == expected[3],
			expected[1] .. " consumes " .. recipe.inputs[1] .. " + " ..
			recipe.inputs[2] .. ", not " .. expected[2] .. " + " .. expected[3])
		want(type(recipe.time) == "number" and recipe.time > 0,
			expected[1] .. " has no positive cook time")
		say("wp26_alloy", expected[1], expected[2], expected[3], recipe.time)
	end

	want(#station == 1, #station .. " station recipes, not one")
	local shape = station[1].recipe
	want(#shape == 2 and #shape[1] == 3 and #shape[2] == 3,
		"the station recipe is not a two-row T")
	want(shape[1][1] == "" and shape[1][3] == "" and
		shape[1][2] == "grug_materials:copper_bar" and
		shape[2][1] == "grug_materials:copper_bar" and
		shape[2][2] == "default:furnace" and
		shape[2][3] == "grug_materials:tin_bar",
		"the station recipe is not 2 Copper Bars + 1 Tin Bar around a furnace")
	say("wp26_station", smelting.NODE, "default:furnace",
		"grug_materials:copper_bar x2", "grug_materials:tin_bar x1")

	-- ==================================================================
	-- 3. The chain is reachable from mined items alone
	-- ==================================================================
	local have = {}
	for _, resource in ipairs(materials.RESOURCES) do
		have[resource.raw_item] = 0
	end
	have["default:coal_lump"] = 0
	local depth = {}
	for round = 1, 10 do
		local grew = false
		for _, row in ipairs(EXPECTED_SMELTS) do
			if have[row[2]] and not have[row[1]] then
				have[row[1]] = have[row[2]] + 1
				depth[row[1]] = have[row[1]]
				grew = true
			end
		end
		for _, recipe in ipairs(smelting.RECIPES) do
			local a, b = recipe.inputs[1], recipe.inputs[2]
			if have[a] and have[b] and not have[recipe.output] then
				have[recipe.output] = math.max(have[a], have[b]) + 1
				depth[recipe.output] = have[recipe.output]
				grew = true
			end
		end
		if not grew then
			say("wp26_closure_rounds", round)
			break
		end
	end
	for _, bar in ipairs(LADDER) do
		want(have[bar] ~= nil, bar .. " is not reachable from mined items")
		say("wp26_reachable", bar, depth[bar])
	end

	-- ==================================================================
	-- 4. Every input exists; nothing regional, cultural or a trophy
	-- ==================================================================
	local forbidden = {}
	for _, resource in ipairs(materials.RESOURCES) do
		if resource.scope == "regional" then
			forbidden[resource.raw_item] = "regional gem"
			if resource.cut_item then
				forbidden[resource.cut_item] = "regional gem"
			end
			if resource.block_node then
				forbidden[resource.block_node] = "regional gem"
			end
		end
	end
	local cultural_keys = {}
	for key in pairs(materials.CULTURAL_MATERIALS) do
		cultural_keys[#cultural_keys + 1] = key
	end
	table.sort(cultural_keys)
	for _, key in ipairs(cultural_keys) do
		forbidden[materials.CULTURAL_MATERIALS[key].item] = "cultural material"
	end

	local touched, touched_order = {}, {}
	local function touch(itemname, role)
		want(registered[itemname] ~= nil,
			"unregistered " .. role .. ": " .. itemname)
		want(forbidden[itemname] == nil, (forbidden[itemname] or "") ..
			" used as " .. role .. ": " .. itemname)
		want(not itemname:find("trophy", 1, true) and
			not itemname:find("crown", 1, true),
			"trophy used as " .. role .. ": " .. itemname)
		if not touched[itemname] then
			touched[itemname] = true
			touched_order[#touched_order + 1] = itemname
		end
	end
	for _, row in ipairs(EXPECTED_SMELTS) do
		touch(row[1], "smelt output")
		touch(row[2], "smelt input")
	end
	for _, recipe in ipairs(smelting.RECIPES) do
		touch(recipe.output, "alloy output")
		touch(recipe.inputs[1], "alloy input")
		touch(recipe.inputs[2], "alloy input")
	end
	say("wp26_items_touched", #touched_order, "forbidden_ids",
		(function()
			local n = 0
			for _ in pairs(forbidden) do n = n + 1 end
			return n
		end)())

	-- ==================================================================
	-- 5. The twelve storage pairs round-trip, and nothing else does
	-- ==================================================================
	local pack_count = 0
	for _, material in ipairs(materials.PROCESSED_MATERIALS) do
		touch(material.item, "storage item")
		touch(material.block_node, "storage block")
		want(packs[material.block_node] == material.item,
			"nine " .. material.item .. " do not pack into " ..
			material.block_node)
		want(unpacks[material.item .. " 9"] == material.block_node,
			material.block_node .. " does not unpack into nine " ..
			material.item)
		pack_count = pack_count + 1
		say("wp26_storage", material.key, material.kind, material.item,
			material.block_node)
	end
	want(pack_count == 12, pack_count .. " storage pairs, not twelve")
	local pack_total = 0
	for _ in pairs(packs) do pack_total = pack_total + 1 end
	want(pack_total == 12, pack_total .. " pack recipes, not twelve")
	for _, itemname in ipairs(NEVER) do
		want(packs[itemname] == nil and unpacks[itemname] == nil and
			unpacks[itemname .. " 9"] == nil and
			smelting.recipe_for(itemname) == nil,
			itemname .. " gained a WP26 recipe and must not have one")
	end

	-- ==================================================================
	-- 6. The matcher and the shipped node timer (gates 2 and 3)
	-- ==================================================================
	-- Empty slots never match: `match` is what the timer asks.
	want(smelting.match("", "") == nil, "two empty slots matched a recipe")
	want(smelting.match("grug_materials:iron_bar", "") == nil,
		"one lone Iron Bar matched a recipe")
	want(smelting.match("default:coal_lump", "") == nil,
		"one lone Coal Lump matched a recipe")

	local node_def = nodes[smelting.NODE]
	want(node_def ~= nil, smelting.NODE .. " is not registered")
	want(node_def.on_timer ~= nil and node_def.groups.cracky ~= nil,
		"the dual furnace is not a node-timer machine")
	want((node_def.groups.level or 0) == 0,
		"the dual furnace carries the retired engine level group")
	want(nodes[smelting.NODE_ACTIVE] ~= nil and
		nodes[smelting.NODE_ACTIVE].drop == smelting.NODE,
		"the active node does not drop the inactive one")

	local next_pos = 0
	local function build(input_a, input_b, fuel)
		next_pos = next_pos + 1
		local pos = {x = next_pos, y = 0, z = 0}
		placed[pos.x .. ",0,0"] = {name = smelting.NODE, param2 = 0}
		node_def.on_construct(pos)
		local inv = meta_for(pos):get_inventory()
		inv:set_stack("input", 1, new_stack(input_a))
		inv:set_stack("input", 2, new_stack(input_b))
		inv:set_stack("fuel", 1, new_stack(fuel))
		return pos, inv
	end
	local function run(pos, ticks)
		for _ = 1, ticks do
			node_def.on_timer(pos, 1)
		end
	end

	-- (a) either order, and exactly one of each consumed per output
	for _, order in ipairs({{1, 2}, {2, 1}}) do
		for _, recipe in ipairs(smelting.RECIPES) do
			local first = recipe.inputs[order[1]]
			local second = recipe.inputs[order[2]]
			local pos, inv = build(first .. " 3", second .. " 3",
				"default:coal_lump 9")
			run(pos, recipe.time)
			local out = inv:get_stack("output", 1)
			want(out:get_name() == recipe.output and out:get_count() == 1,
				recipe.output .. " did not appear after " .. recipe.time ..
				" s with inputs in order " .. order[1] .. order[2] ..
				" (got '" .. out:get_name() .. "' x" .. out:get_count() .. ")")
			want(inv:get_stack("input", 1):get_count() == 2 and
				inv:get_stack("input", 2):get_count() == 2,
				recipe.output .. " did not consume exactly one of each input")
			if order[1] == 1 then
				say("wp26_alloy_cooked", recipe.output, recipe.time, "order12")
			else
				say("wp26_alloy_cooked", recipe.output, recipe.time, "order21")
			end
		end
	end

	-- (b) the Steel/Coal contract: Coal in the FUEL slot is only fuel
	local pos, inv = build("grug_materials:iron_bar 3", "",
		"default:coal_lump 9")
	run(pos, 30)
	want(inv:is_empty("output"),
		"an Iron Bar alone with Coal in the fuel slot produced " ..
		inv:get_stack("output", 1):get_name())
	want(inv:get_stack("input", 1):get_count() == 3,
		"an Iron Bar was consumed without a second material")
	say("wp26_fuel_slot_is_not_a_material", "iron_bar+fuel_coal", "30s",
		"no output")

	pos, inv = build("grug_materials:iron_bar 3", "default:coal_lump 3",
		"default:coal_lump 9")
	local steel = smelting.recipe_for("grug_materials:steel_bar")
	run(pos, steel.time)
	want(inv:get_stack("output", 1):get_name() == "grug_materials:steel_bar",
		"Coal in a material slot did not make Steel")
	say("wp26_material_slot_coal", "grug_materials:steel_bar", steel.time)

	-- (c) the fuel-slot filter refuses a non-fuel, and the output slot
	--     refuses a put; both are what keep (b) honest in a real client
	local fake_player = {get_player_name = function() return "kat" end}
	want(node_def.allow_metadata_inventory_put(pos, "fuel", 1,
		new_stack("grug_materials:iron_bar"), fake_player) == 0,
		"the fuel slot accepted an Iron Bar")
	want(node_def.allow_metadata_inventory_put(pos, "fuel", 1,
		new_stack("default:coal_lump"), fake_player) == 1,
		"the fuel slot refused Coal")
	want(node_def.allow_metadata_inventory_put(pos, "output", 1,
		new_stack("grug_materials:steel_bar"), fake_player) == 0,
		"the output slot accepted a put")
	want(node_def.can_dig(pos) == false,
		"a loaded dual furnace could be dug")

	-- (d) one input exhausted stops the run: 3 + 1 makes exactly one bar
	local bronze = smelting.recipe_for("grug_materials:bronze_bar")
	pos, inv = build("grug_materials:copper_bar 3", "grug_materials:tin_bar 1",
		"default:coal_lump 9")
	run(pos, bronze.time * 4)
	want(inv:get_stack("output", 1):get_count() == 1,
		"3 Copper + 1 Tin made " .. inv:get_stack("output", 1):get_count() ..
		" Bronze Bars, not exactly one")
	want(inv:get_stack("input", 1):get_count() == 2 and
		inv:is_empty("input") == false,
		"the surplus Copper was not left alone")
	say("wp26_one_of_each", "copper3+tin1", 1, "copper_left",
		inv:get_stack("input", 1):get_count())

	-- (e) no fuel, no smelt
	pos, inv = build("grug_materials:copper_bar 3", "grug_materials:tin_bar 3",
		"")
	run(pos, 30)
	want(inv:is_empty("output"), "the furnace smelted without fuel")
	say("wp26_no_fuel_no_smelt", "30s", "no output")

	-- ==================================================================
	-- 7. The §3.8 audit extension, and its negative test
	-- ==================================================================
	local PRICES = {
		["grug_materials:iron_bar"] = 3,
		["default:iron_lump"] = 3,
		["mobs:leather"] = 2,
		["mobs:meat_raw"] = 2,
	}
	set_global("grug_traders", {
		sell_price = function(itemname) return PRICES[itemname] or 0 end,
	})
	current_mod = "grug_traders"
	dofile(repo .. "/mods/ENTITIES/grug_traders/audit_alloys.lua")
	local traders = rawget(_G, "grug_traders")
	want(type(traders.alloy_loop_findings) == "function",
		"audit_alloys.lua published no walk")

	local clean = traders.alloy_loop_findings(smelting.RECIPES)
	want(#clean == 0, "the shipped alloys report " .. #clean ..
		" money loop(s): " .. table.concat(clean, "; "))
	say("wp26_audit_shipped", #smelting.RECIPES, "findings", #clean)

	-- THE NEGATIVE TEST. A synthetic overpriced `dualfurn` recipe -- 4c of
	-- priced inputs turned into 27c of priced output -- must be caught by
	-- the very function `grug_traders` calls at startup.
	local synthetic = {{output = "grug_materials:iron_bar 9",
		inputs = {"mobs:leather", "mobs:meat_raw"}}}
	local caught = traders.alloy_loop_findings(synthetic)
	want(#caught == 1, "the overpriced synthetic recipe produced " ..
		#caught .. " finding(s), not one")
	want(caught[1]:find("27c", 1, true) and caught[1]:find("4c", 1, true),
		"the finding does not name the 27c output and the 4c inputs: " ..
		caught[1])
	say("wp26_audit_negative", "27c_out_4c_in", "findings", #caught)

	-- An unpriced input is an unknown, not a free lunch: the same synthetic
	-- recipe with one unpriced input must stay silent.
	local unknown = traders.alloy_loop_findings({{
		output = "grug_materials:iron_bar 9",
		inputs = {"mobs:leather", "grug_materials:tin_bar"}}})
	want(#unknown == 0,
		"an unpriced input was judged as a money loop: " ..
		table.concat(unknown, "; "))
	say("wp26_audit_unpriced_is_unknown", "findings", #unknown)

	say("wp26_captured_mods_loaded_callbacks", #mods_loaded)
	end)

	restore_globals()
	if not checked then
		error(failure, 0)
	end
	return table.concat(report)
end
