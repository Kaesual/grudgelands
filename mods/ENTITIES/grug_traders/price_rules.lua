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

--
-- Lots (Round 48, sell plan §3.2-§3.4 under round48-plan.md ruling 2.2).
-- Values below are integer milli-copper (mc, 1c = 1000 mc): no fractions.
--

M.MILLI = 1000

-- The lot sizes, smallest first; 99 is the stack size.
M.LOTS = {1, 2, 5, 10, 20, 50, 99}

-- What the vendor pays for a value in mc: copper, lot. The lot is the
-- smallest size whose value reaches 1c, and it pays floor(value × lot / 1000)
-- copper; lot 1 sells singly (3500 mc pays 3c each). 0, nil when even 99 are
-- worth less than 1c.
function M.lot_offer(value)
	if not value or value <= 0 then
		return 0, nil
	end
	for _, lot in ipairs(M.LOTS) do
		local copper = math.floor(value * lot / M.MILLI)
		if copper >= 1 then
			return copper, lot
		end
	end
	return 0, nil
end

-- The second pass (ruling 2.2): resolve() above runs unchanged and yields
-- today's payout for every item that has one; this one prices, in mc, only
-- the items without one. `data`:
--   first[item]    = copper   resolve()'s result (0 = known, not sellable)
--   bulk[item]     = mc       the explicit bulk table (§3.2)
--   storage[item]  = {item = <content>, count = n}  a storage block: n times
--                             its content's value, no discount (§3.3.3)
--   keep[item]     = true     vendor goods, gear and classified goods: they
--                             keep the first pass (a 1-2c supply stays 0)
--   never[item]    = true     never sellable and no value (§3.4)
--   candidates[item] = true   further items to price (every registered one)
--   recipes_for, group_members  as for resolve()
-- Returns item -> mc for every item whose value is known (0 = known, not
-- sellable), item -> material value (mc; a crafted good before its halving,
-- else its value) for the loop audit, and the set of crafted items.
--
-- Rules, in this order: a first-pass payout above 0 (× 1000), which no other
-- rule moves; the never list; the bulk table; storage blocks; kept goods
-- (their first-pass value); else a crafted good: the material value of its
-- cheapest recipe (inputs summed per output unit, floor; a group by its
-- cheapest member), halved once. Later recipes count a crafted input at its
-- material value before the halving, so the halving is never applied twice
-- along a chain. An item without a usable recipe keeps its first-pass value
-- (a free world material: 0) or none.
--
-- Recipe cycles are common here (pack and unpack, slabs and blocks), so the
-- crafted values are found by repeated passes instead of resolve()'s walk:
-- each pass lowers an item to its cheapest recipe over what is known so far,
-- until nothing changes. Values only fall, so it ends; the result is at most
-- every recipe of each crafted item, which is what the loop audit asks.
M.MAX_PASSES = 100

function M.resolve_values(data)
	local first, bulk, storage = data.first, data.bulk, data.storage
	local keep, never = data.keep, data.never
	local names, seen = {}, {}
	for _, set in ipairs({first, bulk, storage, data.candidates or {}}) do
		for item in pairs(set) do
			if not seen[item] then
				seen[item] = true
				names[#names + 1] = item
			end
		end
	end
	table.sort(names) -- one fixed order

	local material = {} -- item -> mc before the halving
	local crafted, derived = {}, {}
	for _, item in ipairs(names) do
		local paid = first[item]
		if paid and paid > 0 then
			material[item] = paid * M.MILLI
		elseif never[item] then
			material[item] = nil -- no value at all
		elseif bulk[item] then
			material[item] = bulk[item]
		elseif storage[item] then
			derived[#derived + 1] = item
		elseif keep[item] then
			material[item] = paid and paid * M.MILLI
		elseif #data.recipes_for(item) > 0 then
			crafted[item] = true
			derived[#derived + 1] = item
		elseif paid then
			material[item] = 0 -- a free world material without a recipe
		end
	end

	local function final(item)
		local v = material[item]
		return v and crafted[item] and math.floor(v / 2) or v
	end

	local function input_value(name)
		local groups = groups_of(name)
		if not groups then
			return material[name]
		end
		local best
		for _, member in ipairs(data.group_members(groups)) do
			local v = material[member]
			if v and (not best or v < best) then
				best = v
			end
		end
		return best
	end

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

	local function settle()
		for _ = 1, M.MAX_PASSES do
			local changed = false
			for _, item in ipairs(derived) do
				local v
				if storage[item] then
					local content = final(storage[item].item)
					v = content and content * storage[item].count
				else
					v = recipe_value(item)
				end
				if v and (not material[item] or v < material[item]) then
					material[item] = v
					changed = true
				end
			end
			if not changed then return end
		end
	end
	-- A candidate left without a usable recipe keeps its first-pass value (a
	-- free world material, 0) and is no crafted good; recipes that count it
	-- may then fall, so settle again until no such item is left.
	repeat
		settle()
		local seeded = false
		for _, item in ipairs(derived) do
			if crafted[item] and not material[item] and first[item] then
				crafted[item] = nil
				material[item] = first[item] * M.MILLI
				seeded = true
			end
		end
	until not seeded

	local values = {}
	for _, item in ipairs(names) do
		if material[item] then
			values[item] = final(item)
		else
			crafted[item] = nil -- no usable recipe
		end
	end
	return values, material, crafted
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
-- more), `known(item)` whether an item has a value at all; `unit` names the
-- unit of the numbers in the messages ("c" unless given). Round 48: the
-- startup audit judges the combined table in "mc", and `input_price` (price
-- unless given) counts a consumed crafted good at its material value before
-- the halving, as its recipes do: the halving is a discount on selling the
-- crafted form, so turning two slabs back into a block, or a block back into
-- its nine gems, gains nothing a player did not put in.
function M.loop_findings(items, recipes_for, price, known, group_members, unit,
		input_price)
	unit = unit or "c"
	local findings = {}
	local input_value = audit_input_value(input_price or price, known, group_members)
	for _, item in ipairs(items) do
		local out = price(item)
		if out > 0 then
			for _, recipe in ipairs(recipes_for(item)) do
				local sum = recipe_sum(recipe, input_value)
				local count = math.max(1, recipe.count)
				if sum and out * count > sum then
					findings[#findings + 1] = "'" .. item .. "' x" .. count ..
						" pays " .. out * count .. unit .. " but its " .. recipe.method ..
						" recipe consumes only " .. sum .. unit .. " (" ..
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
