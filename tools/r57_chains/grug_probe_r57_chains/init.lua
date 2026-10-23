-- Disposable Round 57 CHAINDEPTH probe (never shipped): one second after
-- every mod has loaded, writes <world>/r57_chains_dump.lua with what the game
-- registered, as the game holds it:
--   registry    grug_jobs.recipes (Basic, Cooking, the primaries, Alchemy);
--   furnace     every engine "cooking" route: output, count, input;
--   alloys      grug_smelting.RECIPES (the dual furnace);
--   operations  the station operations (enchants and upgrades);
--   groups      the members of every group token the rows above name;
--   items       description (first line) and kind of every item named;
--   aliases     every alias a row names, resolved;
--   grid        the number of engine grid ("normal") routes left (the craft
--               grid has no slots since Round 45: none of them is a step).
-- Run through tools/r57_chains/dump.sh.
local P = "[r57chains_probe] "

local function literal(value, indent)
	local kind = type(value)
	if kind == "string" then return ("%q"):format(value) end
	if kind == "number" or kind == "boolean" then return tostring(value) end
	if kind ~= "table" then return ("%q"):format(tostring(value)) end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then return a < b end
		return type(a) == "number"
	end)
	local inner = indent .. "\t"
	local parts = {}
	for _, key in ipairs(keys) do
		local name = type(key) == "number" and ("[" .. key .. "]") or
			(key:match("^[%a_][%w_]*$") and key or ("[" .. ("%q"):format(key) .. "]"))
		parts[#parts + 1] = inner .. name .. " = " .. literal(value[key], inner)
	end
	if #parts == 0 then return "{}" end
	return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
end

local function entries(list)
	local result = {}
	for index, entry in ipairs(list or {}) do
		result[index] = entry.group and {group = entry.group, n = entry.n} or
			{item = entry.item, n = entry.n}
	end
	return result
end

local function dump()
	local names = {}
	for name in pairs(core.registered_items) do names[#names + 1] = name end
	table.sort(names)
	local tokens, wanted = {}, {}
	local function want(name)
		if type(name) ~= "string" or name == "" then return end
		if name:match("^group:") then tokens[name] = true else wanted[name] = true end
	end
	local function want_entries(list)
		for _, entry in ipairs(list) do
			want(entry.group and ("group:" .. entry.group) or entry.item)
		end
	end

	local registry = {}
	for index, recipe in ipairs(grug_jobs.recipes) do
		registry[index] = {id = recipe.id, output = recipe.output, count = recipe.count,
			ingredients = entries(recipe.ingredients), area = recipe.area,
			profession = recipe.profession, tier = recipe.tier, station = recipe.station}
		want(recipe.output)
		want_entries(registry[index].ingredients)
	end

	local furnace, grid = {}, 0
	for _, name in ipairs(names) do
		for _, route in ipairs(core.get_all_craft_recipes(name) or {}) do
			local method = route.method or "normal"
			if method == "cooking" then
				local output = ItemStack(route.output or name)
				local input = route.items and route.items[1] or ""
				furnace[#furnace + 1] = {output = output:get_name(),
					count = output:get_count(), input = input, time = route.time}
				want(output:get_name())
				want(input)
			elseif method == "normal" then
				grid = grid + 1
			end
		end
	end

	local alloys = {}
	for index, recipe in ipairs(grug_smelting.RECIPES) do
		alloys[index] = {output = recipe.output, inputs = {recipe.inputs[1], recipe.inputs[2]},
			time = recipe.time}
		want(recipe.output)
		want(recipe.inputs[1])
		want(recipe.inputs[2])
	end

	local operations = {}
	for index, recipe in ipairs(grug_jobs.station_operations()) do
		operations[index] = {id = recipe.id, operation = recipe.operation,
			profession = recipe.profession, tier = recipe.tier, station = recipe.station,
			preview = recipe.output_name, family = recipe.family,
			families = recipe.families, stat = recipe.enchant_stat,
			channel = recipe.enchant_channel, ingredients = entries(recipe.ingredients),
			weapon_extra = entries(recipe.weapon_extra)}
		want(recipe.output_name)
		want_entries(operations[index].ingredients)
		want_entries(operations[index].weapon_extra)
	end

	local groups = {}
	for token in pairs(tokens) do
		local members = {}
		local group_list = token:match("^group:(.+)$")
		for _, name in ipairs(names) do
			local all = true
			for group in group_list:gmatch("[^,]+") do
				if core.get_item_group(name, group) <= 0 then all = false break end
			end
			if all then members[#members + 1] = name end
		end
		groups[token] = members
		for _, name in ipairs(members) do wanted[name] = true end
	end

	local aliases, items = {}, {}
	for name in pairs(wanted) do
		local target = core.registered_aliases[name]
		if target and not core.registered_items[name] then aliases[name] = target end
		local definition = core.registered_items[target or name]
		if definition then
			-- Colour and translation escapes out, then the first line.
			local text = (definition.description or ""):gsub("\27%(.-%)", ""):gsub("\27.", "")
			text = text:match("^[^\n]*") or ""
			items[target or name] = {description = text, type = definition.type}
		end
	end

	local result = {registry = registry, furnace = furnace, alloys = alloys,
		operations = operations, groups = groups, items = items, aliases = aliases,
		grid = grid}
	local path = core.get_worldpath() .. "/r57_chains_dump.lua"
	local file = assert(io.open(path, "w"))
	file:write("-- Generated by tools/r57_chains/dump.sh (grug_probe_r57_chains).\n")
	file:write("return " .. literal(result, "") .. "\n")
	file:close()
	core.log("action", P .. ("RESULT PASS registry=%d furnace=%d alloys=%d operations=%d grid=%d"):format(
		#registry, #furnace, #alloys, #operations, grid))
	core.request_shutdown("r57 chains probe done", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(1, dump)
end)
