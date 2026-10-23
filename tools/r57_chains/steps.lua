-- Round 57 lane CHAINDEPTH: the probe's dump as crafted steps for chains.lua.
--
--   local steps_from_dump = dofile(ROOT .. "/tools/r57_chains/steps.lua")
--   local input = steps_from_dump(dump)
--
-- `dump` has the probe's shape (grug_probe_r57_chains/init.lua): `registry`
-- (grug_jobs.recipes rows), `furnace` ({output, count, input} engine cooking
-- routes), `alloys` (grug_smelting.RECIPES rows), `groups` ("group:<name>"
-- -> members) and `aliases`. Returns
--   steps            the chains.analyse input: registry rows by their id,
--                    "furnace:<output><<input>" and "alloy:<output>";
--   members          group name -> members;
--   by_id, producers the steps by id and by output;
--   meta[id]         {area_label, tier, label}: the area a step belongs to
--                    (Basic, Furnace, Dual Furnace, Cooking, Alchemy or a
--                    primary's name), its tier, "Basic" or "Weaponsmith T3";
--   area_order       the area labels in report order;
--   area_label(area) the label of a registry area or profession;
--   resolve_entries  aliases resolved in an ingredient list.
local LABELS = {basic = "Basic", furnace = "Furnace", dual_furnace = "Dual Furnace",
	cooking = "Cooking", alchemist = "Alchemy", weaponsmith = "Weaponsmith",
	armorsmith = "Armorsmith", tailor = "Tailor", leatherworker = "Leatherworker",
	woodcarver = "Woodcarver", goldsmith = "Goldsmith"}
local ORDER = {"Basic", "Furnace", "Dual Furnace", "Cooking", "Alchemy", "Weaponsmith",
	"Armorsmith", "Tailor", "Leatherworker", "Woodcarver", "Goldsmith"}

return function(dump)
	local aliases = dump.aliases or {}
	local function resolve(name)
		local seen = 0
		while aliases[name] and seen < 8 do name, seen = aliases[name], seen + 1 end
		return name
	end
	local function entry_of(token_or_entry, n)
		if type(token_or_entry) == "table" then
			if token_or_entry.group then return {group = token_or_entry.group, n = token_or_entry.n} end
			return {item = resolve(token_or_entry.item), n = token_or_entry.n}
		end
		local group = token_or_entry:match("^group:(.+)$")
		if group then return {group = group, n = n or 1} end
		return {item = resolve(token_or_entry), n = n or 1}
	end
	local function resolve_entries(list)
		local result = {}
		for index, entry in ipairs(list) do result[index] = entry_of(entry) end
		return result
	end
	local function area_label(area) return LABELS[area] or area end

	local steps, meta, by_id, producers = {}, {}, {}, {}
	local function add(step, area, tier)
		steps[#steps + 1] = step
		by_id[step.id] = step
		producers[step.output] = producers[step.output] or {}
		table.insert(producers[step.output], step)
		local label = area_label(area)
		meta[step.id] = {area_label = label, tier = tier,
			label = (area == "basic" or not tier) and label or (label .. " T" .. tier)}
	end
	for _, row in ipairs(dump.registry or {}) do
		add({id = row.id, output = resolve(row.output), count = row.count or 1,
			ingredients = resolve_entries(row.ingredients), basic = row.area == "basic"},
			row.area, row.area ~= "basic" and row.tier or nil)
	end
	for _, row in ipairs(dump.furnace or {}) do
		local output = resolve(row.output)
		add({id = "furnace:" .. output .. "<" .. row.input, output = output,
			count = row.count or 1, ingredients = {entry_of(row.input, 1)}}, "furnace")
	end
	for _, row in ipairs(dump.alloys or {}) do
		local output = resolve(row.output)
		add({id = "alloy:" .. output, output = output, count = 1,
			ingredients = {entry_of(row.inputs[1], 1), entry_of(row.inputs[2], 1)}},
			"dual_furnace")
	end
	local members = {}
	for key, list in pairs(dump.groups or {}) do
		local group = key:match("^group:(.+)$") or key
		local names = {}
		for index, name in ipairs(list) do names[index] = resolve(name) end
		members[group] = names
	end
	return {steps = steps, members = members, by_id = by_id, producers = producers,
		meta = meta, area_order = ORDER, area_label = area_label,
		resolve_entries = resolve_entries}
end
