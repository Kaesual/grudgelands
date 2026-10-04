-- The vendor payout rules (economy-vendor-plan.md §2.4/§3, economy.md §2) as
-- pure functions: no engine global is read here, so the portable fixture
-- (tools/r29_e1/portable_test.lua) loads exactly these bytes. prices.lua
-- feeds them from the registries once every mod has loaded.

local M = {}

-- Common weapon axis divided by 25c (economy.md §2): the same ×2.5 index as
-- gear and quest copper, so time-to-buy stays constant across tiers.
M.TIER_FACTOR = {1, 2.6, 6.4, 16, 40, 100}

-- T1 value of each loot class in copper, tuned once so the median kill of
-- each level band lands near three copper times the tier factor
-- (economy-vendor-plan.md §3.2; tools/r29_e1/band_payout.sh prints it).
M.CLASS_VALUE = {trash = 1, raw = 1, generic = 2, signature = 7, gem = 4}

-- payout = max(1, round(class value × tier factor)); 0 for anything that has
-- no class or no tier 1..6.
function M.payout(class, tier)
	local value = M.CLASS_VALUE[class]
	local factor = M.TIER_FACTOR[tier]
	if not value or not factor then
		return 0
	end
	return math.max(1, math.floor(value * factor + 0.5))
end

-- Buy-back of an item a vendor sells: 5 % of its price rounded up to the next
-- copper, and 0 (not sellable) where that would not stay below the
-- discounted purchase price, so buying and selling back never pays.
function M.buyback(price, discounted)
	local back = math.ceil(price / 20)
	if back >= discounted then
		return 0
	end
	return back
end

-- A blue (Uncommon) item pays ×3, a gold (Rare) one ×6 of its Common payout
-- (round33-plan.md §2.1); any other quality pays the Common payout.
M.QUALITY_FACTOR = {[2] = 3, [3] = 6}

function M.quality_payout(payout, quality)
	return payout * (M.QUALITY_FACTOR[quality] or 1)
end

-- "group:a,b" -> {"a", "b"}; nil for a plain item name.
local function groups_of(name)
	local list = name:match("^group:(.+)$")
	if not list then
		return nil
	end
	local groups = {}
	for group in list:gmatch("[^,]+") do
		groups[#groups + 1] = group
	end
	return groups
end

-- Resolves every payout. `data`:
--   classified[item] = {class = <CLASS_VALUE key>, tier = 1..6}  loot, gathered
--   processed[item]  = true        payout = the cheapest recipe's inputs
--   sold[item]       = copper      the lowest price any vendor asks
--   reference[item]  = copper      the reference price of gear no vendor
--                                  sells (T2+ bases, shields, spellbooks,
--                                  trinkets): the same buy-back as if sold
--   free[item]       = true        a free world material (wood, stone, sand,
--                                  glass ...): known, worth 0
--   discounted(price)              the same-race purchase price
--   recipes_for(item)              list of {count = n, inputs = {names}}
--   group_members(groups)          item names in every one of the groups
-- Returns item -> copper for every item whose value is known; 0 means "known
-- and not sellable" (a vendor supply such as thread, or a free world material
-- such as planks, counts 0 in a sum).
--
-- Rules, in this order:
--   * a classified item pays the formula; a processed one never more than its
--     cheapest recipe (Leather that a Leatherworker refines from cheaper
--     leather, ruling 5);
--   * a sold or reference-priced item that has no class pays the 5 %
--     buy-back, capped by its cheapest recipe: the 5 % is a ceiling, and a
--     craft never prints money;
--   * a recipe counts only when every input is known; a group input counts
--     its cheapest known member. An unknown input makes that recipe unknown,
--     not free.
function M.resolve(data)
	local reference = data.reference or {}
	local values, state = {}, {}
	local depth, cuts = 0, 0 -- cuts: recipe cycles met so far
	local value

	local function input_value(name)
		local groups = groups_of(name)
		if not groups then
			return value(name)
		end
		local best
		for _, member in ipairs(data.group_members(groups)) do
			local v = value(member)
			if v and (not best or v < best) then
				best = v
			end
		end
		return best
	end

	-- The cheapest recipe's input value per output unit, or nil.
	local function recipe_value(item)
		local best
		for _, recipe in ipairs(data.recipes_for(item)) do
			local sum = 0
			for _, input in ipairs(recipe.inputs) do
				local v = input_value(input)
				if not v then
					sum = nil
					break
				end
				sum = sum + v
			end
			if sum then
				local per_unit = math.floor(sum / math.max(1, recipe.count))
				if not best or per_unit < best then
					best = per_unit
				end
			end
		end
		return best
	end

	function value(item)
		if state[item] == "done" then
			return values[item]
		end
		if state[item] == "busy" then
			cuts = cuts + 1
			return nil -- a recipe cycle: that path is unknown
		end
		state[item] = "busy"
		depth = depth + 1
		local cuts_before = cuts
		local class = data.classified[item]
		local price = data.sold[item] or reference[item]
		local base
		if class then
			base = M.payout(class.class, class.tier)
		elseif price then
			base = M.buyback(price, data.discounted(price))
		elseif data.free[item] then
			base = 0
		end
		local result = base
		if data.processed[item] or (price and not class) then
			local cap = recipe_value(item)
			if cap and (not result or cap < result) then
				result = cap
			end
		end
		depth = depth - 1
		if depth == 0 or cuts == cuts_before then
			values[item] = result
			state[item] = "done"
		else
			-- Met a cycle through an item still being valued (a storage
			-- block inside its own unit): value it again on its own walk.
			state[item] = nil
		end
		return result
	end

	local names = {}
	for item in pairs(data.classified) do names[#names + 1] = item end
	for item in pairs(data.processed) do names[#names + 1] = item end
	for item in pairs(data.sold) do names[#names + 1] = item end
	for item in pairs(reference) do names[#names + 1] = item end
	for item in pairs(data.free) do names[#names + 1] = item end
	table.sort(names) -- one fixed walk order
	for _, item in ipairs(names) do
		value(item)
	end
	return values
end

-- The summed input value of one recipe, or nil when an input is unknown.
local function recipe_sum(recipe, input_value)
	local sum = 0
	for _, input in ipairs(recipe.inputs) do
		local v = input_value(input)
		if not v then
			return nil
		end
		sum = sum + v
	end
	return sum
end

-- Input value for the audits: a known item's payout, a group's cheapest
-- known member, else nil.
local function audit_input_value(price, known, group_members)
	return function(name)
		local groups = groups_of(name)
		if not groups then
			return known(name) and price(name) or nil
		end
		local best
		for _, member in ipairs(group_members(groups)) do
			if known(member) and (not best or price(member) < best) then
				best = price(member)
			end
		end
		return best
	end
end

-- Sold goods that pay a buy-back although no recipe that makes them can be
-- judged: an unpriced input may be a free world material that should count 0,
-- and then the buy-back would be money from nothing. Returns item names.
function M.unjudged_sold(items, recipes_for, price, known, group_members)
	local input_value = audit_input_value(price, known, group_members)
	local found = {}
	for _, item in ipairs(items) do
		local recipes = recipes_for(item)
		if price(item) > 0 and #recipes > 0 then
			local judged = false
			for _, recipe in ipairs(recipes) do
				if recipe_sum(recipe, input_value) then judged = true break end
			end
			if not judged then found[#found + 1] = item end
		end
	end
	table.sort(found)
	return found
end

-- The anti-loop rule (ruling 5): an output may pay at most what its consumed
-- inputs pay. Returns one message per recipe that pays more, sorted. Same
-- input rules as resolve(): unknown inputs make the recipe unknown, a group
-- counts its cheapest known member. `price(item)` is the final payout (0 or
-- more), `known(item)` whether an item has a value at all.
function M.loop_findings(items, recipes_for, price, known, group_members)
	local findings = {}
	local input_value = audit_input_value(price, known, group_members)
	for _, item in ipairs(items) do
		local out = price(item)
		if out > 0 then
			for _, recipe in ipairs(recipes_for(item)) do
				local sum = recipe_sum(recipe, input_value)
				local count = math.max(1, recipe.count)
				if sum and out * count > sum then
					findings[#findings + 1] = "'" .. item .. "' x" .. count ..
						" pays " .. out * count .. "c but its " .. recipe.method ..
						" recipe consumes only " .. sum .. "c (" ..
						table.concat(recipe.inputs, ", ") .. ")"
				end
			end
		end
	end
	table.sort(findings)
	return findings
end

-- The shelf rule (economy-vendor-plan.md §2.4): a vendor never sells an
-- enchant input and never a material above T1. `entries` is a list of
-- {kind = <vendor kind>, item = <name>}; `enchant_inputs` a set; `tier_of`
-- the item's own tier or nil. Returns the failing entries with a reason.
function M.shelf_findings(entries, enchant_inputs, tier_of)
	local failed = {}
	for _, entry in ipairs(entries) do
		local tier = tier_of(entry.item)
		local reason
		if enchant_inputs[entry.item] then
			reason = "enchant input"
		elseif tier and tier > 1 then
			reason = "tier " .. tier .. " material"
		end
		if reason then
			failed[#failed + 1] = {kind = entry.kind, item = entry.item, reason = reason}
		end
	end
	return failed
end

return M
