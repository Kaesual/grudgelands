-- Disposable engine probe for WP26's dual furnace.
--
-- The headless KAT (`tools/wp26/smelting_kat.lua`) drives the shipped node
-- timer against a stub inventory, which proves the ARITHMETIC. What only a
-- real server can say is whether a dual furnace placed in a world runs at all:
-- whether its node timer is stepped, whether `set_node` builds its inventory,
-- whether the engine's fuel resolution burns Coal for as long as the timer
-- assumes, and how long a smelt really takes in wall-clock seconds -- which is
-- the calibration number the task card's §1 asks WP26 to measure rather than
-- freeze.
--
-- So this places three furnaces in one forceloaded mapblock, feeds them and
-- polls once a second:
--
--   A  Copper Bar + Tin Bar + Coal fuel        -> a Bronze Bar
--   B  Iron Bar ALONE + Coal in the FUEL slot  -> nothing, ever (gate 2)
--   C  Iron Bar + Coal in a MATERIAL slot      -> a Steel Bar   (gate 2)
--
-- and then asks the shipped anti-loop walk, in the running engine, to catch a
-- deliberately overpriced synthetic `dualfurn` recipe (gate 4).
--
-- Staged with PROBE=, never shipped.

local BASE = {x = 8, y = 104, z = 8}
local POLL_SECONDS = 45

local problems = {}

local function log(line)
	core.log("action", "[probe] " .. line)
end

local function complain(line)
	problems[#problems + 1] = line
end

-- `dofile`/`io` are restricted under secure.enable_security, but the game and
-- mod directories stay readable (AGENTS.md), which is all this needs.
local function texture_exists(modname, filename)
	local handle = io.open(core.get_modpath(modname) .. "/textures/" ..
		filename, "rb")
	if not handle then
		return false
	end
	handle:close()
	return true
end

local CASES = {
	{key = "A_bronze", offset = 0,
		input_a = "grug_materials:copper_bar 3",
		input_b = "grug_materials:tin_bar 3",
		fuel = "default:coal_lump 9",
		expect = "grug_materials:bronze_bar"},
	{key = "B_coal_is_only_fuel", offset = 2,
		input_a = "grug_materials:iron_bar 3",
		input_b = "",
		fuel = "default:coal_lump 9",
		expect = false},
	{key = "C_coal_is_a_material", offset = 4,
		input_a = "grug_materials:iron_bar 3",
		input_b = "default:coal_lump 3",
		fuel = "default:coal_lump 9",
		expect = "grug_materials:steel_bar"},
}

local function case_pos(case)
	return {x = BASE.x + case.offset, y = BASE.y, z = BASE.z}
end

local function place(case)
	local pos = case_pos(case)
	-- `set_node` runs `on_construct`, which is what sizes the three lists.
	core.set_node(pos, {name = grug_smelting.NODE, param2 = 0})
	local inv = core.get_meta(pos):get_inventory()
	if inv:get_size("input") ~= grug_smelting.INPUT_SLOTS or
			inv:get_size("fuel") ~= 1 then
		complain(case.key .. ": on_construct did not build the inventory")
		return
	end
	inv:set_stack("input", 1, ItemStack(case.input_a))
	inv:set_stack("input", 2, ItemStack(case.input_b))
	inv:set_stack("fuel", 1, ItemStack(case.fuel))
	-- Direct inventory writes bypass `on_metadata_inventory_put`, so the
	-- timer this node is driven by is started explicitly. A player's put
	-- starts it through the callback.
	core.get_node_timer(pos):start(1.0)
	log("placed " .. case.key .. " at " .. core.pos_to_string(pos) .. ": '" ..
		case.input_a .. "' + '" .. case.input_b .. "' + fuel '" ..
		case.fuel .. "'")
end

local function poll(case, second)
	if case.done then
		return
	end
	local pos = case_pos(case)
	local inv = core.get_meta(pos):get_inventory()
	local out = inv:get_stack("output", 1)
	if out:is_empty() then
		return
	end
	case.done = true
	case.first_output_second = second
	case.output_name = out:get_name()
	case.output_count = out:get_count()
	case.input_left = {inv:get_stack("input", 1):get_count(),
		inv:get_stack("input", 2):get_count()}
	case.node_after = core.get_node(pos).name
	log("case " .. case.key .. ": first output after " .. second .. " s -- " ..
		case.output_name .. " x" .. case.output_count .. ", inputs left " ..
		case.input_left[1] .. "/" .. case.input_left[2] .. ", node " ..
		case.node_after)
end

local function judge()
	for _, case in ipairs(CASES) do
		local recipe = case.expect and
			grug_smelting.recipe_for(case.expect) or nil
		if case.expect == false then
			if case.done then
				complain(case.key .. " produced " .. case.output_name ..
					" after " .. case.first_output_second ..
					" s; Coal in the fuel slot must never stand in for a " ..
					"material (items_crafting.md 3.0.2)")
			else
				local inv = core.get_meta(case_pos(case)):get_inventory()
				log("case " .. case.key .. " PASS: nothing after " ..
					POLL_SECONDS .. " s, " ..
					inv:get_stack("input", 1):get_count() ..
					" Iron Bar(s) still in slot 1")
			end
		elseif not case.done then
			complain(case.key .. " produced nothing in " .. POLL_SECONDS ..
				" s; expected " .. case.expect)
		else
			if case.output_name ~= case.expect or case.output_count < 1 then
				complain(case.key .. " produced " .. case.output_name ..
					" x" .. case.output_count .. ", not " .. case.expect)
			end
			-- EXACTLY ONE OF EACH PER OUTPUT. Stated as the invariant rather
			-- than as "2 left", so a poll that arrives one tick late (and
			-- therefore sees two bars) still tests the right thing.
			if 3 - case.input_left[1] ~= case.output_count or
					3 - case.input_left[2] ~= case.output_count then
				complain(case.key .. " left " .. case.input_left[1] .. "/" ..
					case.input_left[2] .. " of 3/3 inputs for " ..
					case.output_count .. " output(s): one of each input " ..
					"must be consumed per output")
			end
			if case.first_output_second < recipe.time then
				complain(case.key .. " produced its first bar after " ..
					case.first_output_second .. " s, faster than its " ..
					recipe.time .. " s cook time")
			end
			if case.node_after ~= grug_smelting.NODE_ACTIVE then
				complain(case.key .. " is " .. case.node_after ..
					" while still burning, not " .. grug_smelting.NODE_ACTIVE)
			end
			log("case " .. case.key .. " MEASURED: " .. case.expect ..
				" after " .. case.first_output_second ..
				" s wall clock; registered cook time " .. recipe.time .. " s")
		end
	end

	-- The §3.5 audit extension, in the running engine: the shipped recipes are
	-- clean, and an overpriced synthetic one is caught by the same walk.
	local clean = grug_traders.alloy_loop_findings(grug_smelting.RECIPES)
	if #clean ~= 0 then
		complain("the shipped alloys report " .. #clean .. " money loop(s)")
	end
	local caught = grug_traders.alloy_loop_findings({{
		output = "grug_materials:iron_bar 9",
		inputs = {"mobs:leather", "mobs:meat_raw"}}})
	if #caught ~= 1 then
		complain("the overpriced synthetic dualfurn recipe produced " ..
			#caught .. " finding(s), not one")
	else
		log("audit negative test: " .. caught[1])
	end
	log("audit over " .. #grug_smelting.RECIPES ..
		" shipped dualfurn recipes: " .. #clean .. " finding(s)")

	-- The engine's own craft system, on the two shapes a player uses.
	local station = core.get_craft_result({method = "normal", width = 3,
		items = {ItemStack(""), ItemStack("grug_materials:copper_bar"),
			ItemStack(""), ItemStack("grug_materials:copper_bar"),
			ItemStack("default:furnace"), ItemStack("grug_materials:tin_bar")}})
	if station.item:get_name() ~= grug_smelting.NODE then
		complain("the T-arrangement crafts '" .. station.item:get_name() ..
			"', not " .. grug_smelting.NODE)
	else
		log("station recipe: 2 Copper Bars + 1 Tin Bar + a furnace -> " ..
			station.item:get_name())
	end
	local cooked = core.get_craft_result({method = "cooking", width = 1,
		items = {ItemStack("default:copper_lump")}})
	log("normal furnace: default:copper_lump -> " .. cooked.item:get_name() ..
		" in " .. cooked.time .. " s")

	-- Both stored textures really are on disk under the names the node uses.
	for _, filename in ipairs({"grug_smelting_dual_furnace_front.png",
			"grug_smelting_dual_furnace_front_active.png"}) do
		if not texture_exists("grug_smelting", filename) then
			complain("missing texture: " .. filename)
		end
	end

	if #problems > 0 then
		table.sort(problems)
		for _, message in ipairs(problems) do
			core.log("error", "[probe] " .. message)
		end
	else
		log("PROBE PASS: the dual furnace smelts, the fuel slot is not a " ..
			"material slot, and the anti-loop walk fires")
	end
end

--
-- D. The mid-cook slot swap (review 2026-09-16, finding 1), in the engine.
--
-- A Steel is cooked part-way, then BOTH material slots become a Bronze, which
-- is two seconds shorter. Progress on one alloy is not progress on another, so
-- nothing new may come out until the Bronze has had its own cook time.
--
-- The assertion is deliberately "no NEW output within three seconds of the
-- swap" rather than "no output at second N": the probe polls at one-second
-- granularity and the server may run the node timer before or after a given
-- `core.after`, so whether the Steel itself finished first is a coin toss --
-- while the property under test holds either way. With the bug the Bronze
-- appears on the very next tick.
--
local SWAP = {key = "D_midcook_swap", offset = 6, at = 4, window = 3,
	expect = "grug_materials:bronze_bar"}

local function swap_pos()
	return {x = BASE.x + SWAP.offset, y = BASE.y, z = BASE.z}
end

local function swap_place()
	local pos = swap_pos()
	core.set_node(pos, {name = grug_smelting.NODE, param2 = 0})
	local inv = core.get_meta(pos):get_inventory()
	inv:set_stack("input", 1, ItemStack("grug_materials:iron_bar 3"))
	inv:set_stack("input", 2, ItemStack("default:coal_lump 3"))
	inv:set_stack("fuel", 1, ItemStack("default:coal_lump 9"))
	core.get_node_timer(pos):start(1.0)
	log("placed " .. SWAP.key .. " at " .. core.pos_to_string(pos) ..
		": Iron Bar + mined Coal, to be swapped to Copper + Tin at t+" ..
		SWAP.at .. " s")
end

local function output_count(inv)
	local total = 0
	for slot = 1, 2 do
		total = total + inv:get_stack("output", slot):get_count()
	end
	return total
end

local function output_holds(inv, itemname)
	for slot = 1, 2 do
		local stack = inv:get_stack("output", slot)
		if stack:get_name() == itemname then
			return stack:get_count()
		end
	end
	return 0
end

local function swap_do()
	local inv = core.get_meta(swap_pos()):get_inventory()
	SWAP.before = output_count(inv)
	inv:set_stack("input", 1, ItemStack("grug_materials:copper_bar 3"))
	inv:set_stack("input", 2, ItemStack("grug_materials:tin_bar 3"))
	log(SWAP.key .. ": swapped both material slots at t+" .. SWAP.at ..
		" s; output held " .. SWAP.before .. " item(s) at that moment")
end

local function swap_watch(second)
	local inv = core.get_meta(swap_pos()):get_inventory()
	local now = output_count(inv)
	if now > SWAP.before and not SWAP.early then
		SWAP.early = second
		SWAP.early_name = inv:get_stack("output", 1):get_name()
	end
end

local function swap_judge()
	local inv = core.get_meta(swap_pos()):get_inventory()
	if SWAP.early then
		complain(SWAP.key .. ": a new bar came out " .. SWAP.early ..
			" s after the swap (" .. tostring(SWAP.early_name) ..
			"), inside the " .. SWAP.window .. " s the shorter recipe still " ..
			"needed -- the old recipe's progress was carried over")
	else
		log(SWAP.key .. " PASS: nothing new for " .. SWAP.window ..
			" s after the swap")
	end
	local bronze = output_holds(inv, SWAP.expect)
	if bronze < 1 then
		complain(SWAP.key .. ": no " .. SWAP.expect ..
			" after the swapped-in recipe's own cook time")
	else
		log(SWAP.key .. ": " .. bronze .. " " .. SWAP.expect ..
			" after the swap, inputs left " ..
			inv:get_stack("input", 1):get_count() .. "/" ..
			inv:get_stack("input", 2):get_count())
	end
end

local function run()
	for _, case in ipairs(CASES) do
		place(case)
	end
	swap_place()
	for second = 1, POLL_SECONDS do
		core.after(second, function()
			for _, case in ipairs(CASES) do
				poll(case, second)
			end
		end)
	end
	core.after(SWAP.at, swap_do)
	for offset = 1, SWAP.window do
		core.after(SWAP.at + offset, function() swap_watch(offset) end)
	end
	core.after(SWAP.at + 12, swap_judge)
	core.after(POLL_SECONDS + 1, judge)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local min = {x = BASE.x - 8, y = BASE.y - 8, z = BASE.z - 8}
		local max = {x = BASE.x + 8, y = BASE.y + 8, z = BASE.z + 8}
		core.emerge_area(min, max, function(_, _, remaining)
			if remaining ~= 0 then
				return
			end
			-- A node timer is only stepped inside an ACTIVE mapblock, and with
			-- no player on the server the only way to make one active is to
			-- forceload it (`limit = -1` lifts max_forceloaded_blocks).
			if not core.forceload_block(BASE, true, -1) then
				complain("could not forceload " .. core.pos_to_string(BASE))
			end
			log("forceloaded " .. core.pos_to_string(BASE) ..
				", placing three dual furnaces")
			core.after(1, run)
		end)
	end)
end)
