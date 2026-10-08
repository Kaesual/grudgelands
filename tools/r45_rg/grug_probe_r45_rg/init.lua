-- Disposable Round 45 RG probe (never shipped): after every mod has loaded,
-- writes <world>/r45_rg_corpus.lua with
--   engine     every grid ("normal") route the engine holds: output, count,
--              width and the slot items ("" for an empty slot);
--   gear       every grid output that is equipment: its family and bracket;
--   registry   grug_jobs.recipes, whichever record shape the branch has;
--   groups     the members of every group token the routes above use;
--   payouts    the vendor payout of every item the price module pays for;
--   operations the station operations per kind.
-- Run through tools/r45_rg/dump_corpus.sh.
local P = "[r45rg_probe] "
local function log(text) core.log("action", P .. text) end

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

local function maximum_index(value)
	local maximum = 0
	for key in pairs(value or {}) do
		if type(key) == "number" and key > maximum then maximum = key end
	end
	return maximum
end

local function name_of(value)
	if type(value) == "string" then return value:match("^%s*([^%s]+)") or "" end
	if type(value) == "userdata" or type(value) == "table" then
		if type(value.get_name) == "function" then return value:get_name() end
	end
	return ""
end

local function copy_plain(value, depth)
	depth = depth or 0
	if depth > 4 then return nil end
	local kind = type(value)
	if kind == "string" or kind == "number" or kind == "boolean" then return value end
	if kind == "userdata" and type(value.to_string) == "function" then return value:to_string() end
	if kind ~= "table" then return nil end
	local result = {}
	for key, item in pairs(value) do
		if type(key) == "string" or type(key) == "number" then
			result[key] = copy_plain(item, depth + 1)
		end
	end
	return result
end

local REGISTRY_FIELDS = {"id", "profession", "area", "tier", "station", "time",
	"progress", "material", "in_place", "operation", "mastery_required",
	"output", "output_name", "count", "ingredients", "flat_inputs", "inputs",
	"shapeless", "hint"}

local function dump()
	local names = {}
	for name in pairs(core.registered_items) do names[#names + 1] = name end
	table.sort(names)
	local engine, gear, tokens = {}, {}, {}
	for _, name in ipairs(names) do
		for _, recipe in ipairs(core.get_all_craft_recipes(name) or {}) do
			if (recipe.method or "normal") == "normal" then
				local output = ItemStack(recipe.output or name)
				local items = {}
				for index = 1, maximum_index(recipe.items) do
					items[index] = name_of(recipe.items[index])
					if items[index]:match("^group:") then tokens[items[index]] = true end
				end
				engine[#engine + 1] = {output = output:get_name(),
					count = output:get_count(), width = tonumber(recipe.width) or 0,
					items = items}
				local family = grug_items.family_for(ItemStack(output:get_name()))
				local def = core.registered_items[output:get_name()] or {}
				if family and family ~= "tool" then
					gear[output:get_name()] = {family = family,
						bracket = def._grug_bracket, ilvl = def._grug_ilvl}
				end
			end
		end
	end
	local registry = {}
	for index, recipe in ipairs(grug_jobs.recipes or {}) do
		local row = {}
		for _, field in ipairs(REGISTRY_FIELDS) do row[field] = copy_plain(recipe[field]) end
		for _, token in ipairs(recipe.flat_inputs or {}) do
			if token:match("^group:") then tokens[token] = true end
		end
		for _, entry in ipairs(recipe.ingredients or {}) do
			if entry.group then tokens["group:" .. entry.group] = true end
		end
		registry[index] = row
	end
	local groups = {}
	for token in pairs(tokens) do
		local members = {}
		local wanted = token:match("^group:(.+)$")
		for _, name in ipairs(names) do
			local all = true
			for group in wanted:gmatch("[^,]+") do
				if core.get_item_group(name, group) <= 0 then all = false break end
			end
			if all then members[#members + 1] = name end
		end
		groups[token] = members
	end
	local payouts = {}
	for _, name in ipairs(names) do
		local price = grug_traders.sell_price(name)
		if price and price > 0 then payouts[name] = price end
	end
	local operations = {}
	for _, recipe in ipairs(grug_jobs.station_operations and
			grug_jobs.station_operations() or {}) do
		operations[recipe.operation] = (operations[recipe.operation] or 0) + 1
	end
	local corpus = {engine = engine, gear = gear, registry = registry,
		groups = groups, payouts = payouts, operations = operations}
	local path = core.get_worldpath() .. "/r45_rg_corpus.lua"
	local file = assert(io.open(path, "w"))
	file:write("-- Generated by tools/r45_rg/dump_corpus.sh (grug_probe_r45_rg).\n")
	file:write("return " .. literal(corpus, "") .. "\n")
	file:close()
	local paid = 0
	for _ in pairs(payouts) do paid = paid + 1 end
	log(("RESULT PASS engine=%d registry=%d payouts=%d enchants=%d upgrades=%d"):format(
		#engine, #registry, paid, operations.enchant or 0, operations.upgrade or 0))
	core.request_shutdown("r45 rg probe done", false, 0)
end

core.register_on_mods_loaded(function()
	core.after(1, dump)
end)
