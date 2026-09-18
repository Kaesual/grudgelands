-- Known-answer test for FISHING (WP13 playtest round 5, 2026-09-16).
--
-- Three rulings are under test, and each one is checked against the real
-- sources rather than a transcription of them:
--
--   A  SIX LEVEL-BAND TABLES. Round 8 replaced the original worldwide table;
--      `table_for` now follows the authoritative zone level while salt and
--      fresh water remain equally valid.
--   B  THE BITE IS A DELAY, and both ends of it live in one place.
--   C+D THE MECHANIC. `mods/ITEMS/grug_fishing/init.lua` is loaded under a
--      stub engine, its real registrations are read back, and the real
--      right-click closure and the real globalstep are then DRIVEN through
--      eight cases: a cast that lands, a cast reeled in early, an angler who
--      walks off, an angler who puts the rod away, water that is gone, a
--      right-click on dry land, a full pack, and the tick before the bite --
--      which is the negative control, because a fixture in which the catch
--      arrives whatever the clock says is checking nothing.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp13/fishing_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/fishing_kat.lua")("."))'

local M = {}

local INIT = "mods/ITEMS/grug_fishing/init.lua"

-- Where each catch item is registered, transcribed INDEPENDENTLY of the catch
-- table so that an item renamed on one side and not the other is a failure and
-- not a silent "you caught nothing". The pattern is the one
-- `tools/wp13/start_npcs_kat.lua` uses for the activity tools.
local CATCH_SOURCE = {
	["grug_mobs:raw_fish"] = {"mods/ENTITIES/grug_mobs/items.lua",
		"register_craftitem(\"grug_mobs:raw_fish\""},
	["default:stick"] = {"mods/BASE/default/craftitems.lua",
		"register_craftitem(\"default:stick\""},
	["default:papyrus"] = {"mods/BASE/default/nodes.lua",
		"register_node(\"default:papyrus\""},
	["grug_fishing:silver_trout"] = {INIT, "{\"silver_trout\""},
	["grug_fishing:mire_carp"] = {INIT, "{\"mire_carp\""},
	["grug_fishing:frostfin"] = {INIT, "{\"frostfin\""},
	["grug_fishing:ember_eel"] = {INIT, "{\"ember_eel\""},
	["grug_fishing:storm_tuna"] = {INIT, "{\"storm_tuna\""},
}

-- The rod's two ingredients, likewise transcribed rather than read off the
-- recipe the fixture is judging.
local RECIPE_SOURCE = {
	["default:stick"] = CATCH_SOURCE["default:stick"],
	["grug_mobs:spider_silk"] = {"mods/ENTITIES/grug_mobs/items.lua",
		"material(\"spider_silk\""},
}

local function read_file(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local body = handle:read("*a")
	handle:close()
	return body
end

--
-- A tiny stub engine: only what `init.lua` actually touches, so that a call it
-- grows tomorrow is a loud nil rather than a quiet no-op.
--

local function new_stack(itemstring)
	local name, count = itemstring:match("^(%S+)%s+(%d+)$")
	if not name then
		name, count = itemstring, 1
	end
	local stack = {_name = name, _count = tonumber(count) or 1, _wear = 0}
	function stack:get_name() return self._name end
	function stack:get_count() return self._count end
	function stack:get_wear() return self._wear end
	function stack:is_empty() return self._name == "" or self._count == 0 end
	function stack:add_wear(amount) self._wear = self._wear + amount end
	return stack
end

local function build_harness(repo)
	local harness = {
		tools = {}, craftitems = {}, crafts = {}, eatable = {},
		globalstep = nil, on_leave = {}, on_die = {}, on_mods_loaded = {},
		logs = {}, chat = {}, sounds = {}, dropped = {},
		nodes = {}, rolls = {}, roll_at = 0, fish_level = 1,
	}

	local registered_items = {}
	harness.registered_items = registered_items

	local core_api = {registered_items = registered_items}
	function core_api.get_current_modname() return "grug_fishing" end
	function core_api.get_modpath() return repo .. "/mods/ITEMS/grug_fishing" end
	function core_api.register_tool(name, def)
		def.name = name
		harness.tools[name] = def
		registered_items[name] = def
	end
	function core_api.register_craftitem(name, def)
		def.name = name
		harness.craftitems[name] = def
		registered_items[name] = def
	end
	function core_api.register_craft(def)
		harness.crafts[#harness.crafts + 1] = def
	end
	function core_api.register_globalstep(fn) harness.globalstep = fn end
	function core_api.register_on_leaveplayer(fn)
		harness.on_leave[#harness.on_leave + 1] = fn
	end
	function core_api.register_on_dieplayer(fn)
		harness.on_die[#harness.on_die + 1] = fn
	end
	function core_api.register_on_mods_loaded(fn)
		harness.on_mods_loaded[#harness.on_mods_loaded + 1] = fn
	end
	function core_api.item_eat(hp)
		return function() return hp end
	end
	function core_api.log(level, message)
		-- Space, not a vertical bar: sweep 4 of docs/research/luanti-lua.md
		-- hunts bitwise operators and would read one inside a string as a hit.
		harness.logs[#harness.logs + 1] = level .. " " .. message
	end
	function core_api.chat_send_player(name, message)
		harness.chat[#harness.chat + 1] = name .. " " .. message
	end
	function core_api.sound_play(name, spec)
		harness.sounds[#harness.sounds + 1] = name .. " " ..
			tostring(spec and spec.gain)
	end
	function core_api.add_item(pos, stack)
		harness.dropped[#harness.dropped + 1] = stack:get_name()
	end
	local function key(pos)
		return pos.x .. "," .. pos.y .. "," .. pos.z
	end
	harness.node_key = key
	function core_api.get_node(pos)
		return {name = harness.nodes[key(pos)] or "air"}
	end
	function core_api.get_item_group(name, group)
		local def = registered_items[name]
		if def and def.groups and def.groups[group] then
			return def.groups[group]
		end
		return 0
	end
	function core_api.get_player_by_name(name)
		return harness.players and harness.players[name] or nil
	end

	local vector_api = {}
	function vector_api.distance(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	-- A SCRIPTED PcgRandom. The engine's is seeded from the wall clock on
	-- purpose (a bite should not be predictable); here the queue is the input
	-- of the test, so every row below is a known answer.
	local function pcg()
		local self = {}
		function self:next()
			harness.roll_at = harness.roll_at + 1
			local value = harness.rolls[harness.roll_at]
			if value == nil then
				error("fishing fixture ran out of scripted rolls", 0)
			end
			return value
		end
		return self
	end

	harness.core = core_api
	harness.vector = vector_api
	harness.pcg = pcg
	harness.new_stack = new_stack
	return harness
end

-- A player the mechanic can be driven through.
local function new_player(harness, name, pos, wielded)
	local player = {_name = name, _pos = pos, _wielded = wielded,
		_inventory_full = false, _added = {}}
	function player:is_player() return true end
	function player:get_player_name() return self._name end
	function player:get_pos()
		return {x = self._pos.x, y = self._pos.y, z = self._pos.z}
	end
	function player:get_wielded_item() return self._wielded end
	function player:set_wielded_item(stack) self._wielded = stack end
	function player:get_inventory()
		local owner = self
		return {
			add_item = function(_, _, stack)
				if owner._inventory_full then
					return stack
				end
				owner._added[#owner._added + 1] = stack:get_name()
				return new_stack("")
			end,
		}
	end
	harness.players = harness.players or {}
	harness.players[name] = player
	return player
end

function M.run(repo)
	local out, failures = {}, {}

	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local function check(ok, message)
		if not ok then
			failures[#failures + 1] = message
		end
		return ok
	end
	local function num(value)
		return string.format("%.3f", value)
	end

	--
	-- Load the real mod under the stub engine.
	--
	local harness = build_harness(repo)
	local saved = {}
	for _, key in ipairs({"core", "vector", "PcgRandom", "ItemStack",
			"mobs", "grug_core", "grug_fishing"}) do
		saved[key] = rawget(_G, key)
	end
	rawset(_G, "core", harness.core)
	rawset(_G, "vector", harness.vector)
	rawset(_G, "PcgRandom", harness.pcg)
	rawset(_G, "ItemStack", new_stack)
	rawset(_G, "mobs", {add_eatable = function(name, hp)
		harness.eatable[name] = hp
	end})
	rawset(_G, "grug_core", {mob_level_at = function()
		return harness.fish_level
	end})
	rawset(_G, "grug_fishing", nil)

	-- The stubs stay installed for the WHOLE run, not just for the load: the
	-- mod's own closures look `core`, `vector` and `ItemStack` up as globals
	-- every time they are called, and section D calls them. `restore` therefore
	-- runs at the very end -- which also means a crash inside this fixture
	-- leaves the stubs behind, and that is deliberate: a crashing fixture is a
	-- failure to fix, not a state to paper over.
	local function restore()
		for _, key in ipairs({"core", "vector", "PcgRandom", "ItemStack",
				"mobs", "grug_core", "grug_fishing"}) do
			rawset(_G, key, saved[key])
		end
	end

	local chunk, load_error = loadfile(repo .. "/" .. INIT)
	local ok, run_error
	if chunk then
		ok, run_error = pcall(chunk)
	end
	local fishing = rawget(_G, "grug_fishing")
	if not chunk or not ok then
		restore()
		row("wp13_fishing_result", "FAIL", 1)
		row("wp13_fishing_failure", "cannot load " .. INIT .. ": " ..
			tostring(load_error or run_error))
		return table.concat(out, "\n") .. "\n"
	end

	--
	-- A. one table for each ten-level band
	--
	local catch_table = fishing.table_for({x = 0, y = 0, z = 0})
	check(type(catch_table) == "table" and #catch_table > 0,
		"table_for returned no catch table")

	local sum = 0
	local names = {}
	for _, entry in ipairs(catch_table) do
		sum = sum + entry.weight
		names[#names + 1] = entry.name .. "x" .. entry.count .. "@" ..
			entry.weight
		check(entry.weight > 0, entry.name .. " has a non-positive weight")
		check(entry.count >= 1, entry.name .. " has a non-positive count")
		check(entry.name:match("^[%a_]+:[%a_]+$") ~= nil,
			"'" .. tostring(entry.name) .. "' is not a plain item name")
		local source = CATCH_SOURCE[entry.name]
		if check(source ~= nil, entry.name ..
				" is not one of the items this fixture knows the source of") then
			local body = read_file(repo .. "/" .. source[1])
			check(body ~= nil and body:find(source[2], 1, true) ~= nil,
				entry.name .. " is not registered in " .. source[1])
		end
	end
	row("wp13_fishing_table", table.concat(names, " "), "total",
		tostring(sum))
	check(sum == fishing.CATCH_TOTAL,
		"the weights sum to " .. sum .. " but CATCH_TOTAL is " ..
		tostring(fishing.CATCH_TOTAL))
	check(sum == 100, "the weights are documented as percent but sum to " .. sum)

	-- Every roll in range lands somewhere, and the boundaries are exactly the
	-- cumulative weights: enumerated, not sampled.
	local counted = {}
	for roll = 0, sum - 1 do
		local entry = fishing.catch_at(catch_table, roll)
		if check(entry ~= nil, "roll " .. roll .. " falls through the table") then
			counted[entry.name] = (counted[entry.name] or 0) + 1
		end
	end
	for _, entry in ipairs(catch_table) do
		check(counted[entry.name] == entry.weight, entry.name ..
			" is reachable on " .. tostring(counted[entry.name]) ..
			" rolls, not on its weight of " .. entry.weight)
	end
	-- Out of range must still not return nil: the last entry catches it.
	check(fishing.catch_at(catch_table, sum) ~= nil,
		"a roll at the top of the range falls through")

	local band_fish = {}
	for band = 1, 6 do
		harness.fish_level = (band - 1) * 10 + 1
		local selected = fishing.table_for({x = band, y = 0, z = band})
		check(selected == fishing.CATCH_TABLES[band],
			"table_for chose the wrong level band " .. band)
		local band_total = 0
		for _, entry in ipairs(selected) do
			band_total = band_total + entry.weight
			local source = CATCH_SOURCE[entry.name]
			check(source ~= nil, entry.name .. " has no independent source row")
		end
		check(band_total == 100, "band " .. band .. " weight differs")
		band_fish[#band_fish + 1] = selected[1].name
	end
	harness.fish_level = 1
	row("wp13_fishing_bands", table.concat(band_fish, ","))

	--
	-- B. the bite
	--
	check(fishing.MIN_WAIT > 0, "the bite is instant")
	check(fishing.MAX_WAIT > fishing.MIN_WAIT, "the bite has no spread")
	check(fishing.wait_for(0) == fishing.MIN_WAIT,
		"roll 0 is not the shortest wait")
	check(fishing.wait_for(fishing.WAIT_SPREAD) == fishing.MAX_WAIT,
		"the top roll is not the longest wait")
	local previous = -1
	for roll = 0, fishing.WAIT_SPREAD do
		local wait = fishing.wait_for(roll)
		check(wait > previous, "the wait is not strictly increasing at roll " ..
			roll)
		previous = wait
	end
	check(fishing.wait_for(-5) == fishing.MIN_WAIT, "a low roll is not clamped")
	check(fishing.wait_for(fishing.WAIT_SPREAD + 5) == fishing.MAX_WAIT,
		"a high roll is not clamped")
	row("wp13_fishing_bite", "min", num(fishing.MIN_WAIT), "max",
		num(fishing.MAX_WAIT), "spread", tostring(fishing.WAIT_SPREAD))

	--
	-- C. the registrations
	--
	local rod = harness.tools["grug_fishing:rod"]
	if check(rod ~= nil, "grug_fishing:rod is not registered as a tool") then
		check(rod.groups and rod.groups.fishing_rod == 1,
			"the rod does not carry the fishing_rod group -- the wield pose " ..
			"and the mechanic both dispatch on it")
		check(rod.liquids_pointable == true,
			"the rod cannot point at water (default:water_source is " ..
			"pointable = false)")
		check(rod.inventory_image == "grug_fishing_rod.png",
			"the rod does not use the shipped sprite")
		check(read_file(repo ..
			"/mods/ITEMS/grug_fishing/textures/grug_fishing_rod.png") ~= nil,
			"the rod's sprite is not on disk")
		local caps = rod.tool_capabilities
		check(caps ~= nil and next(caps.groupcaps or {}) == nil,
			"the rod digs -- a rod is not a spade")
		check(caps ~= nil and next(caps.damage_groups or {}) == nil,
			"the rod is a weapon -- it must do no damage")
		check(rod.groups.grug_equip_weapon == nil,
			"the rod claims the weapon slot")
		check(rod._grug_sell_price == nil,
			"the rod carries a vendor price; nothing in this lane needs one")
	end

	local cooked = harness.craftitems["grug_fishing:cooked_fish"]
	if check(cooked ~= nil, "grug_fishing:cooked_fish is not registered") then
		check(type(cooked.on_use) == "function", "the cooked fish is not food")
		check(cooked.on_use() == 8,
			"the cooked fish does not restore what cooked meat does")
		check(harness.eatable["grug_fishing:cooked_fish"] == 8,
			"the cooked fish is not in mobs_redo's eatable table")
		check(cooked.groups and cooked.groups.food_fish == 1,
			"the cooked fish carries no food_fish group")
		-- The anti-loop statement: the traders' audit only walks recipes whose
		-- OUTPUT has a price, so an unpriced cooked fish cannot print money.
		check(cooked._grug_sell_price == nil,
			"the cooked fish carries a vendor price -- then the §3.8 " ..
			"anti-loop rule has to be argued against the raw fish's 2c")
	end

	local rod_recipes, cooking = 0, 0
	for _, recipe in ipairs(harness.crafts) do
		if recipe.type == "cooking" then
			cooking = cooking + 1
			check(recipe.output == "grug_fishing:cooked_fish" and
				recipe.recipe == "grug_mobs:raw_fish",
				"the cooking recipe is not raw fish -> cooked fish")
		elseif recipe.output == "grug_fishing:rod" then
			rod_recipes = rod_recipes + 1
			for _, line in ipairs(recipe.recipe) do
				for _, item in ipairs(line) do
					if item ~= "" then
						local source = RECIPE_SOURCE[item]
						if check(source ~= nil, "the rod recipe names " ..
								item .. ", which this fixture cannot place") then
							local body = read_file(repo .. "/" .. source[1])
							check(body ~= nil and
								body:find(source[2], 1, true) ~= nil,
								item .. " is not registered in " .. source[1])
						end
					end
				end
			end
		end
	end
	check(rod_recipes == 2, "there are " .. rod_recipes ..
		" rod recipes, not the mirrored pair")
	check(cooking == 1, "there are " .. cooking .. " cooking recipes, not one")
	row("wp13_fishing_items", "rod_recipes", tostring(rod_recipes), "cooking",
		tostring(cooking), "eat", tostring(cooked and cooked.on_use()))

	--
	-- D. the mechanic, driven
	--
	local step = harness.globalstep
	check(type(step) == "function", "the mod registered no globalstep")

	local SALT_WATER = "default:water_source"
	local FRESH_WATER = "default:river_water_source"
	harness.registered_items[SALT_WATER] = {groups = {water = 3}}
	harness.registered_items[FRESH_WATER] = {groups = {water = 3}}
	harness.registered_items["default:stone"] = {groups = {cracky = 3}}
	harness.registered_items["grug_mobs:raw_fish"] =
		{description = "Raw Fish", groups = {food_fish_raw = 1}}
	harness.registered_items["default:stick"] = {description = "Stick",
		groups = {}}
	harness.registered_items["default:papyrus"] = {description = "Papyrus",
		groups = {}}

	local POND = {x = 10, y = 3, z = 10}
	harness.nodes[harness.node_key(POND)] = SALT_WATER
	local RIVER = {x = 12, y = 3, z = 10}
	harness.nodes[harness.node_key(RIVER)] = FRESH_WATER
	local DRY = {x = 10, y = 3, z = 12}
	harness.nodes[harness.node_key(DRY)] = "default:stone"

	local function fresh_rod()
		return new_stack("grug_fishing:rod")
	end
	local function pointed(pos)
		return {type = "node", under = {x = pos.x, y = pos.y, z = pos.z}}
	end

	-- `step` is the only clock: one call of `dtime` seconds.
	local function tick(seconds)
		step(seconds)
	end

	local case_rows = {}
	local function case(label, body)
		harness.chat = {}
		harness.sounds = {}
		harness.dropped = {}
		local result = body()
		case_rows[#case_rows + 1] = label .. "=" .. result
		row("wp13_fishing_case", label, result)
	end

	-- D1. THE CAST THAT LANDS. Rolls: the bite (0 -> the shortest wait) and
	-- then the catch (0 -> the first table entry, the fish).
	case("lands", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "angler", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		-- The negative control: one tick short of the bite must give nothing.
		tick(fishing.MIN_WAIT - 0.6)
		check(#player._added == 0,
			"the catch arrived before the bite -- the clock is not being read")
		local early = #player._added
		tick(1.0)
		check(#player._added == 1, "the cast never landed")
		check(player._added[1] == "grug_mobs:raw_fish",
			"roll 0 did not land the first entry of the table")
		check(player._wielded:get_wear() > 0, "a catch did not wear the rod")
		check(#harness.sounds == 2,
			"a cast and a catch did not make one sound each")
		-- A second tick must not pay twice.
		tick(30)
		check(#player._added == 1, "the same cast landed twice")
		return "early=" .. early .. " caught=" .. tostring(player._added[1]) ..
			" wear=" .. player._wielded:get_wear()
	end)

	-- D1b. The mechanic dispatches on the water group, so river water and salt
	-- water both cast through the same zone-level table selection.
	case("fresh_water", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "river_angler",
			{x = 12, y = 4, z = 9}, fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(RIVER))
		tick(60)
		check(player._added[1] == "grug_mobs:raw_fish",
			"fresh water did not use the level-band catch table")
		return "caught=" .. tostring(player._added[1])
	end)

	-- D2. REELED IN EARLY. The second right-click is the only way to stop
	-- waiting, and it must not pay a catch or wear the rod.
	case("reeled_in", function()
		harness.rolls = {0}
		harness.roll_at = 0
		local player = new_player(harness, "quitter", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		tick(60)
		check(#player._added == 0, "a reeled-in line still caught something")
		check(player._wielded:get_wear() == 0,
			"reeling in early wore the rod")
		return "caught=" .. #player._added .. " chat=" .. #harness.chat
	end)

	-- D3. WALKED OFF. Two rolls are queued although a correct run draws only
	-- the bite: a mutation that lets the line hold would otherwise run the
	-- queue dry and CRASH the fixture instead of failing it, and a crash is a
	-- worse answer than a red row. The same is true of D4 and D5.
	case("walked_off", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "wanderer", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		player._pos = {x = 200, y = 4, z = 200}
		tick(60)
		check(#player._added == 0, "the line held from 200 nodes away")
		return "caught=" .. #player._added .. " chat=" .. #harness.chat
	end)

	-- D4. ROD PUT AWAY.
	case("rod_away", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "swapper", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		player._wielded = new_stack("default:stone")
		tick(60)
		check(#player._added == 0, "a stone in the hand still landed a fish")
		return "caught=" .. #player._added .. " chat=" .. #harness.chat
	end)

	-- D5. THE POND DRAINED.
	case("water_gone", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "drainer", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		harness.nodes[harness.node_key(POND)] = "air"
		tick(60)
		harness.nodes[harness.node_key(POND)] = SALT_WATER
		check(#player._added == 0, "a fish came out of thin air")
		return "caught=" .. #player._added .. " chat=" .. #harness.chat
	end)

	-- D6. DRY LAND. No cast at all, so no roll is drawn, and `roll_at == 0`
	-- below is the assertion that says so. The queue is nevertheless stocked --
	-- the review of 2026-09-16 pointed out that an EMPTY queue turns the
	-- mutation this case exists to catch (remove the `is_water` gate) into a
	-- Lua error rather than a red row, and a crash is a worse answer than a
	-- failure. Same reasoning as D3-D5.
	case("dry_land", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "optimist", {x = 10, y = 4, z = 11},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(DRY))
		tick(60)
		check(#player._added == 0, "stone gave up a fish")
		check(harness.roll_at == 0, "a cast at stone still drew a bite roll")
		return "caught=" .. #player._added .. " rolls=" .. harness.roll_at
	end)

	-- D7. FULL PACK. The catch must reach the ground rather than vanish.
	case("full_pack", function()
		harness.rolls = {0, 0}
		harness.roll_at = 0
		local player = new_player(harness, "hoarder", {x = 10, y = 4, z = 9},
			fresh_rod())
		player._inventory_full = true
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		tick(60)
		check(#player._added == 0, "the full pack accepted the catch")
		check(#harness.dropped == 1 and
			harness.dropped[1] == "grug_mobs:raw_fish",
			"a catch into a full pack was lost instead of dropped")
		return "dropped=" .. tostring(harness.dropped[1])
	end)

	-- D8. THE JUNK END OF THE TABLE. The last weight must be reachable through
	-- the real mechanic, not only through `catch_at`.
	case("junk", function()
		harness.rolls = {0, sum - 1}
		harness.roll_at = 0
		local player = new_player(harness, "unlucky", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		tick(60)
		local last = catch_table[#catch_table].name
		check(player._added[1] == last,
			"the top roll landed " .. tostring(player._added[1]) ..
			" rather than the table's last entry " .. last)
		return "caught=" .. tostring(player._added[1])
	end)

	-- The leave hook drops a line rather than leaving a dangling player name.
	case("left_server", function()
		harness.rolls = {0}
		harness.roll_at = 0
		local player = new_player(harness, "leaver", {x = 10, y = 4, z = 9},
			fresh_rod())
		rod.on_place(player:get_wielded_item(), player, pointed(POND))
		for _, fn in ipairs(harness.on_leave) do
			fn(player)
		end
		tick(60)
		check(#player._added == 0, "a departed angler still landed a fish")
		return "caught=" .. #player._added
	end)

	--
	-- The startup audit has to be clean on the real table.
	--
	harness.logs = {}
	for _, fn in ipairs(harness.on_mods_loaded) do
		fn()
	end
	local errors = 0
	local clean_count = false
	for _, line in ipairs(harness.logs) do
		if line:sub(1, 5) == "error" then
			errors = errors + 1
		end
		if line:find("action [grug_fishing] tables=6 entries=18 ", 1, true) then
			clean_count = true
		end
	end
	check(errors == 0, "the startup audit reported " .. errors .. " error(s)")
	check(#harness.logs >= 1, "the startup audit printed nothing at all")
	check(clean_count, "the startup audit did not report entries=18")
	row("wp13_fishing_audit", "lines", tostring(#harness.logs), "errors",
		tostring(errors), "entries", "18")

	local band6_name = fishing.CATCH_TABLES[6][1].name
	fishing.CATCH_TABLES[6][1].name = "missing:band6_fish"
	harness.logs = {}
	for _, fn in ipairs(harness.on_mods_loaded) do fn() end
	fishing.CATCH_TABLES[6][1].name = band6_name
	local missing_reported = false
	for _, line in ipairs(harness.logs) do
		if line:sub(1, 5) == "error" and
				line:find("missing:band6_fish", 1, true) then
			missing_reported = true
		end
	end
	check(missing_reported,
		"the startup audit accepted an unregistered band-6 catch")
	row("wp13_fishing_audit_mutation", "band6_missing", "reported")

	restore()

	table.sort(failures)
	row("wp13_fishing_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, message in ipairs(failures) do
		row("wp13_fishing_failure", message)
	end
	return table.concat(out, "\n") .. "\n"
end

return function(repo)
	return M.run(repo)
end
