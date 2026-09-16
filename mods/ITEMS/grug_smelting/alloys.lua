-- The `dualfurn` recipe registry (task card §3.5, "Auditable recipe registry").
--
-- LotT keys its dual-furnace recipes by OUTPUT in one shared table
-- (`lottblocks/crafting.lua:30-34`, `lottblocks.crafts[output_name]`), which
-- makes a second recipe for the same output silently overwrite the first and
-- forces the matcher to walk every entry of every recipe type on every timer
-- tick (`:55-73`). This port keeps LotT's semantics -- two material inputs,
-- either slot order, one of each consumed, one output -- and drops both
-- defects: recipes are a LIST, and the matcher is an O(1) lookup on the
-- unordered input pair.
--
-- `grug_smelting.RECIPES` is the public, iterable read surface the task card
-- makes binding, because `grug_traders`' anti-loop audit cannot see these
-- recipes through the engine at all: its walk judges only `normal` and
-- `cooking` engine recipes (`CONSUMING_METHODS`, `grug_traders/init.lua`).
-- Nothing here calls into the engine, so this file also loads under the
-- headless KAT (`tools/wp26/smelting_kat.lua`) as real shipped code.

-- Every registered alloy, in registration order. One entry per output:
--   {output = "mod:item", inputs = {"mod:a", "mod:b"}, time = <seconds>}
-- `inputs` is ordered as registered; the matcher accepts both orders.
grug_smelting.RECIPES = {}

-- The dual furnace has exactly two material slots. The number is named once
-- here so the node, the matcher and the KAT cannot drift apart.
grug_smelting.INPUT_SLOTS = 2

local by_pair = {}
local by_output = {}

local function pair_key(first, second)
	if first <= second then
		return first .. "\0" .. second
	end
	return second .. "\0" .. first
end

local function bad(message)
	error("grug_smelting: " .. message, 0)
end

-- Register one two-input alloy. `cook_time` is runtime calibration, never a
-- frozen number (task card §1, "No number freezing").
function grug_smelting.register_alloy(output, input_a, input_b, cook_time)
	if type(output) ~= "string" or output == "" then
		bad("an alloy needs an output itemstring")
	end
	if type(input_a) ~= "string" or input_a == "" or
			type(input_b) ~= "string" or input_b == "" then
		bad("alloy " .. output .. " needs two material inputs")
	end
	cook_time = tonumber(cook_time)
	if not cook_time or cook_time ~= cook_time or cook_time <= 0 then
		bad("alloy " .. output .. " needs a positive cook time")
	end
	if by_output[output] then
		bad("alloy " .. output .. " is already registered")
	end
	local key = pair_key(input_a, input_b)
	if by_pair[key] then
		bad("the input pair of " .. output .. " already produces " ..
			by_pair[key].output)
	end
	local recipe = {output = output, inputs = {input_a, input_b},
		time = cook_time}
	grug_smelting.RECIPES[#grug_smelting.RECIPES + 1] = recipe
	by_output[output] = recipe
	by_pair[key] = recipe
	return recipe
end

-- The either-order matcher. Both slots must carry a material: an empty slot
-- has the name "" and no recipe names it, so a lone Iron Bar next to burning
-- Coal in the FUEL slot matches nothing (task card gate 2).
function grug_smelting.match(first, second)
	if type(first) ~= "string" or first == "" or
			type(second) ~= "string" or second == "" then
		return nil
	end
	return by_pair[pair_key(first, second)]
end

function grug_smelting.recipe_for(output)
	return by_output[output]
end
