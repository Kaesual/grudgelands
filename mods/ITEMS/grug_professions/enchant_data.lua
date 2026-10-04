-- Pure checks and lookups for the data-driven enchant and upgrade catalogs
-- (Round 28 ruling 28; Round 33, docs/design/item_tiers.md §2, §3). No engine
-- calls: the mod and the portable tests load this file with dofile.
--
-- enchants.json is a list with one entry per tier 1..6:
--   {"tier": T, "prefix_loot": {stat: item}, "suffix_loot": {stat: item},
--    "family_input": {family: item}}
-- An enchant of tier T for family F, stat S and channel K costs the family's
-- own material of tier T + K_loot[S] + family_input[F]. The trinket's prefix
-- pool uses prefix_loot, its suffix pool suffix_loot.
--
-- upgrades.json is a list with one entry per profession and tier:
--   {"tier": T, "profession": P, "families": [F...], "own_material_count": 2,
--    "signatures": [item, item], "target_item_level": 10 T}

local M = {}

local function fail(message)
	error("grug_professions: " .. message, 0)
end

local function is_item(value)
	return type(value) == "string" and value:match("^[%w_]+:[%w_]+$") ~= nil
end

-- Equipment family of a stat pool key: both trinket pools are one family.
function M.family_of_pool(pool_key)
	if pool_key == "trinket_prefix" or pool_key == "trinket_suffix" then return "trinket" end
	return pool_key
end

-- `pools` is grug_items.POOLS. Returns the sorted family list and the set of
-- every stat any pool uses.
function M.families_and_stats(pools)
	local families, stats, seen = {}, {}, {}
	for key, pool in pairs(pools) do
		local family = M.family_of_pool(key)
		if not seen[family] then
			seen[family] = true
			families[#families + 1] = family
		end
		for index = 1, #pool do stats[pool[index]] = true end
	end
	table.sort(families)
	return families, stats
end

local LOOT_FIELDS = {"prefix_loot", "suffix_loot"}

-- Validates the decoded enchants.json against the stat pools and returns the
-- rows keyed by tier. Every tier 1..6 appears exactly once; both loot tables
-- name an item for every stat of every pool; every family has a
-- family_input item; no unknown stat or family key (a typo would otherwise
-- go unnoticed).
function M.validate_enchants(rows, pools)
	if type(rows) ~= "table" or #rows == 0 then
		fail("enchants.json must be a non-empty list of tier entries")
	end
	local families, stats = M.families_and_stats(pools)
	local family_set = {}
	for index = 1, #families do family_set[families[index]] = true end
	local stat_list = {}
	for stat in pairs(stats) do stat_list[#stat_list + 1] = stat end
	table.sort(stat_list)
	local by_tier = {}
	for index = 1, #rows do
		local row = rows[index]
		local where = "enchants.json[" .. index .. "]"
		if type(row) ~= "table" then fail(where .. " must be an object") end
		local tier = row.tier
		if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6 then
			fail(where .. " tier must be an integer 1..6")
		end
		if by_tier[tier] then fail("enchants.json lists tier " .. tier .. " twice") end
		where = "enchants.json tier " .. tier
		for _, field in ipairs(LOOT_FIELDS) do
			if type(row[field]) ~= "table" then fail(where .. " needs " .. field) end
			for stat, item in pairs(row[field]) do
				if not stats[stat] then
					fail(where .. " " .. field .. " has unknown stat " .. tostring(stat))
				end
				if not is_item(item) then
					fail(where .. " " .. field .. "." .. stat .. " is not an item name")
				end
			end
			for _, stat in ipairs(stat_list) do
				if not row[field][stat] then
					fail(where .. " has no " .. field .. " entry for stat " .. stat)
				end
			end
		end
		if type(row.family_input) ~= "table" then fail(where .. " needs family_input") end
		for family, item in pairs(row.family_input) do
			if not family_set[family] then
				fail(where .. " family_input has unknown family " .. tostring(family))
			end
			if not is_item(item) then
				fail(where .. " family_input." .. family .. " is not an item name")
			end
		end
		for _, family in ipairs(families) do
			if not row.family_input[family] then
				fail(where .. " has no family_input entry for family " .. family)
			end
		end
		by_tier[tier] = row
	end
	for tier = 1, 6 do
		if not by_tier[tier] then fail("enchants.json has no entry for tier " .. tier) end
	end
	return by_tier
end

-- The three material tokens of one enchant operation.
function M.operation_inputs(by_tier, family, stat, channel, tier, own_material)
	local row = by_tier[tier]
	if not row then fail("no enchant data for tier " .. tostring(tier)) end
	if not is_item(own_material) then
		fail(family .. " T" .. tier .. " has no own material")
	end
	local field = channel == "suffix" and "suffix_loot" or "prefix_loot"
	local loot = row[field][stat]
	if not loot then
		fail("enchants.json tier " .. tier .. " has no " .. field .. " entry for stat " .. stat)
	end
	local input = row.family_input[family]
	if not input then
		fail("enchants.json tier " .. tier .. " has no family_input entry for family " .. family)
	end
	return {own_material, loot, input}
end

-- Validates the decoded upgrades.json: one entry per profession of
-- `families_of` (profession -> sorted family list, the owners of
-- item_tiers.md §3.3) and tier 1..6, with exactly those families, two own
-- materials, two signature items and the target item level 10 T. Returns
-- the rows keyed by profession, then tier.
function M.validate_upgrades(rows, families_of)
	if type(rows) ~= "table" or #rows == 0 then
		fail("upgrades.json must be a non-empty list")
	end
	local by_profession = {}
	for index = 1, #rows do
		local row = rows[index]
		local where = "upgrades.json[" .. index .. "]"
		if type(row) ~= "table" then fail(where .. " must be an object") end
		local tier, profession = row.tier, row.profession
		if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > 6 then
			fail(where .. " tier must be an integer 1..6")
		end
		local owned = families_of[profession]
		if not owned then fail(where .. " has unknown profession " .. tostring(profession)) end
		where = "upgrades.json " .. profession .. " T" .. tier
		by_profession[profession] = by_profession[profession] or {}
		if by_profession[profession][tier] then fail(where .. " is listed twice") end
		local listed = {}
		for _, family in ipairs(type(row.families) == "table" and row.families or {}) do
			listed[#listed + 1] = family
		end
		table.sort(listed)
		if table.concat(listed, ",") ~= table.concat(owned, ",") then
			fail(where .. " families differ from the profession's (" ..
				table.concat(owned, ", ") .. ")")
		end
		if row.own_material_count ~= 2 then fail(where .. " needs two own materials") end
		if type(row.signatures) ~= "table" or #row.signatures ~= 2 or
				not is_item(row.signatures[1]) or not is_item(row.signatures[2]) then
			fail(where .. " needs two signature items")
		end
		if row.target_item_level ~= 10 * tier then
			fail(where .. " target item level must be " .. 10 * tier)
		end
		by_profession[profession][tier] = row
	end
	for profession in pairs(families_of) do
		for tier = 1, 6 do
			if not (by_profession[profession] or {})[tier] then
				fail("upgrades.json has no entry for " .. profession .. " T" .. tier)
			end
		end
	end
	return by_profession
end

-- The four material tokens of one upgrade operation.
function M.upgrade_inputs(row, own_material)
	if not is_item(own_material) then
		fail(row.profession .. " T" .. row.tier .. " has no own material")
	end
	return {own_material, own_material, row.signatures[1], row.signatures[2]}
end

-- Every item the enchant data names, with a readable location, for the
-- registered-item check at mods-loaded time.
function M.referenced_items(by_tier)
	local result = {}
	for tier = 1, 6 do
		local row = by_tier[tier]
		for _, field in ipairs({"prefix_loot", "suffix_loot", "family_input"}) do
			local keys = {}
			for key in pairs(row[field]) do keys[#keys + 1] = key end
			table.sort(keys)
			for _, key in ipairs(keys) do
				result[#result + 1] = {item = row[field][key],
					where = "enchants.json tier " .. tier .. " " .. field .. "." .. key}
			end
		end
	end
	return result
end

-- Operation inputs whose declared ingredient tier is above the operation's
-- tier (the rule profession recipes already follow). `tier_of` is
-- grug_jobs.ingredient_tier; undeclared items have no tier and pass.
function M.over_tier_inputs(operations, tier_of)
	local offences = {}
	for index = 1, #operations do
		local op = operations[index]
		for input_index = 1, #op.inputs do
			local input = op.inputs[input_index]
			local tier = tier_of(input)
			if tier and tier > op.tier then
				offences[#offences + 1] = op.label .. " (T" .. op.tier .. ") needs " .. input ..
					", a T" .. tier .. " ingredient"
			end
		end
	end
	return offences
end

-- `products` maps an item to the profession whose recipes make it. Returns a
-- list of offences: an operation or recipe of profession P whose input is a
-- product of another profession.
function M.foreign_inputs(products, recipes)
	local offences = {}
	for index = 1, #recipes do
		local recipe = recipes[index]
		for input_index = 1, #recipe.inputs do
			local input = recipe.inputs[input_index]
			local maker = products[input]
			if maker and maker ~= recipe.profession then
				offences[#offences + 1] = recipe.profession .. " " .. recipe.label ..
					" needs " .. input .. ", a " .. maker .. " product"
			end
		end
	end
	return offences
end

return M
