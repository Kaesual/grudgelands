-- One bounded process evaluator for shared and personal automatic stations.
-- Only elapsed server game time is accounted; shutdown wall time is excluded.
local automatic = {}
automatic.sizes = {
	furnace = {src = 1, fuel = 1, dst = 4},
	dual_furnace = {input = 2, fuel = 1, output = 2},
	brewing_stand = {mixture = 1, fuel = 1, output = 2},
}

local FURNACE_FUELS = {
	["default:coal_lump"] = 80,
	["grug_smelting:charcoal"] = 80,
}

function automatic.fuel_time(station, stack)
	if station ~= "furnace" and station ~= "dual_furnace" then
		local result = core.get_craft_result({method = "fuel", width = 1,
			items = {stack}})
		return result.time or 0
	end
	local name = stack:get_name()
	if FURNACE_FUELS[name] then return FURNACE_FUELS[name] end
	if core.get_item_group(name, "tree") > 0 then return 15 end
	return 0
end

local function recipe_at(station, inv)
	if station == "furnace" then
		local result, after = core.get_craft_result({method = "cooking", width = 1,
			items = inv:get_list("src")})
		if result.time <= 0 or result.item:is_empty() then return end
		return {output = result.item, time = result.time, list = "src",
			after = after.items, replacements = result.replacements or {}}
	elseif station == "dual_furnace" then
		local recipe = grug_smelting.match(inv:get_stack("input", 1):get_name(),
			inv:get_stack("input", 2):get_name())
		if recipe then return {output = recipe.output, time = recipe.time,
			list = "input", count = 2} end
	else
		local recipe = grug_brewing.match(inv:get_stack("mixture", 1):get_name())
		if recipe then return {output = recipe.output, time = recipe.time,
			list = "mixture", count = 1} end
	end
end

-- Returns complete copies of the destination slots, or nil if anything fails
-- to fit. This also handles replacement items without dropping private work.
local function fit(inv, list, outputs)
	local slots = inv:get_list(list)
	for _, output in ipairs(outputs) do
		local rest = ItemStack(output)
		for index = 1, #slots do
			if not slots[index]:is_empty() then rest = slots[index]:add_item(rest) end
		end
		for index = 1, #slots do
			if slots[index]:is_empty() then rest = slots[index]:add_item(rest) end
		end
		if not rest:is_empty() then return nil end
	end
	return slots
end

automatic.fit = fit

function automatic.personal_light_deadline(now, current, remaining_fuel)
	now = tonumber(now) or 0
	current = tonumber(current) or 0
	remaining_fuel = tonumber(remaining_fuel) or 0
	if remaining_fuel <= 0 then return current end
	return math.max(current, now + math.ceil(remaining_fuel))
end

function automatic.personal_light_active(now, deadline)
	return (tonumber(deadline) or 0) > (tonumber(now) or 0)
end

function automatic.advance(station, inv, state, elapsed)
	local output_list = station == "furnace" and "dst" or "output"
	state.fuel = state.fuel or 0
	state.fuel_total = state.fuel_total or state.fuel
	state.progress = state.progress or 0
	elapsed = math.max(0, elapsed)
	-- Inventory sizes and finite input/fuel stacks bound useful work. The cap
	-- also guards malformed third-party craft callbacks against zero-time loops.
	for _ = 1, 512 do
		local recipe = recipe_at(station, inv)
		local identity = ""
		if recipe then
			local names = {}
			for _, stack in ipairs(inv:get_list(recipe.list)) do names[#names + 1] = stack:get_name() end
			table.sort(names)
			identity = ItemStack(recipe.output):to_string() .. "\0" .. recipe.time .. "\0" .. table.concat(names, "\0")
		end
		if state.recipe ~= identity then state.recipe = identity state.progress = 0 end
		local outputs = recipe and {recipe.output} or {}
		for _, item in ipairs(recipe and recipe.replacements or {}) do
			outputs[#outputs + 1] = item
		end
		local destination = recipe and fit(inv, output_list, outputs)
		if not recipe or not destination then
			state.fuel = math.max(0, state.fuel - elapsed)
			return
		end
		if state.fuel <= 0 then
			-- Brewing keeps its earlier exact-boundary behavior: the next fuel
			-- item is acquired only once positive elapsed time is available.
			if station ~= "furnace" and station ~= "dual_furnace" and elapsed <= 0 then return end
			local fuel_stack = inv:get_stack("fuel", 1)
			local fuel_time = automatic.fuel_time(station, fuel_stack)
			if fuel_time <= 0 then state.progress = 0 return end
			if station == "furnace" or station == "dual_furnace" then
				fuel_stack:take_item(1)
				inv:set_stack("fuel", 1, fuel_stack)
			else
				-- Brewing retains the engine fuel recipe and replacement semantics.
				local fuel, after = core.get_craft_result({method = "fuel", width = 1,
					items = inv:get_list("fuel")})
				local remaining = ItemStack(after.items[1])
				local replacements = fuel.replacements or {}
				if not remaining:is_empty() and core.get_craft_result({method = "fuel",
						width = 1, items = {remaining}}).time <= 0 then
					replacements[#replacements + 1] = remaining
					remaining = ItemStack("")
				end
				local slots = fit(inv, output_list, replacements)
				if not slots then return end
				inv:set_list(output_list, slots)
				inv:set_stack("fuel", 1, remaining)
			end
			state.fuel = fuel_time
			state.fuel_total = fuel_time
		end
		if elapsed <= 0 then return end
		local step = math.min(elapsed, state.fuel, math.max(0, recipe.time - state.progress))
		state.fuel = state.fuel - step
		state.progress = state.progress + step
		elapsed = elapsed - step
		if state.progress >= recipe.time then
			-- Fuel replacements may have used destination room in this iteration.
			destination = fit(inv, output_list, outputs)
			if not destination then return end
			if recipe.after then inv:set_list(recipe.list, recipe.after)
			else
				for index = 1, recipe.count do
					local stack = inv:get_stack(recipe.list, index)
					stack:take_item(1)
					inv:set_stack(recipe.list, index, stack)
				end
			end
			inv:set_list(output_list, destination)
			state.progress = state.progress - recipe.time
		end
	end
end

function automatic.running(station, inv, state)
	if (state.fuel or 0) > 0 then return true end
	local recipe = recipe_at(station, inv)
	if not recipe then return false end
	local output_list = station == "furnace" and "dst" or "output"
	local outputs = {recipe.output}
	for _, item in ipairs(recipe.replacements or {}) do outputs[#outputs + 1] = item end
	return fit(inv, output_list, outputs) ~= nil and
		automatic.fuel_time(station, inv:get_stack("fuel", 1)) > 0
end

function automatic.fractions(station, inv, state)
	local fuel_total = tonumber(state.fuel_total) or 0
	local fuel = fuel_total > 0 and math.max(0, math.min(1,
		(tonumber(state.fuel) or 0) / fuel_total)) or 0
	local recipe = recipe_at(station, inv)
	local progress = recipe and recipe.time > 0 and math.max(0, math.min(1,
		(tonumber(state.progress) or 0) / recipe.time)) or 0
	return fuel, progress
end

return automatic
