-- The one price module (economy-vendor-plan.md §3, economy.md §2). Every
-- vendor payout comes from here, resolved once when every mod has loaded:
--
--   loot and gathered goods  formula: class value × tier factor (§3.1)
--   processed goods          the inputs of their cheapest recipe (bars,
--                            leather grades, bolts, settings, wood grades;
--                            ruling 5)
--   goods a vendor sells     5 % of the price, rounded up (§3.4), never more
--                            than their cheapest recipe's inputs
--   gear no vendor sells     the same, from its reference price (T2+ bases,
--                            shields, spellbooks, trinkets; item_tiers.md
--                            §6.1)
--   free world materials     0, and they count 0 in a recipe (wood, stone,
--                            sand, glass, flowers and their dyes ...), so
--                            nothing made only from them pays
--   everything else          0: not sellable
--
-- That first pass runs unchanged since Round 48 (round48-plan.md ruling 2.2):
-- it yields today's payout for every item that has one. A second pass in
-- milli-copper (price_rules.resolve_values; sell plan §3.2-§3.4) then prices
-- only the items without one:
--
--   bulk goods               the explicit bulk table below (cobble, sand,
--                            leaves, logs, planks ...), sold in lots
--   storage blocks           nine times their bar's payout
--   crafted goods            half the material value of their cheapest
--                            recipe (potions, dishes, seeds, tools, bags ...)
--   vendor goods and gear    keep the first pass (a 1-2c supply stays 0)
--   the never list           not sellable (Bag of Coins, bound and quest
--                            items)
--
-- A value below 1c sells in lots (price_rules.lot_offer: the smallest of 1,
-- 2, 5, 10, 20, 50, 99 worth 1c). A concrete stack of a single good sells at
-- its item's payout times its quality factor (stack_sell_price: blue ×3,
-- gold ×6); sell_offer gives the lot of any stack.
--
-- The rules themselves are pure (price_rules.lua); this file only reads the
-- registries. An item's TIER is read from its own registration, so a tier
-- change there (e.g. a gem's harvest tier) moves its price with no edit here.

local rules = dofile(core.get_modpath("grug_traders") .. "/price_rules.lua")
grug_traders.price_rules = rules

--
-- Classes (§3.1 table). The catalogue (grug_mobs/data/items.json) names most
-- loot by kind; these sets name what does not follow from its kind.
--

-- Trash / food. Stolen purses and war trophies join through their
-- grug_trash_loot group; papyrus is a fishing catch. Sticks are not here:
-- four of them are crafted from two planks of free wood, so traders do not
-- buy them (the bowyer's 2c is below the buy-back floor).
local TRASH = {
	["mobs:meat_raw"] = true, ["grug_mobs:bone"] = true,
	["grug_mobs:feather"] = true, ["grug_mobs:linen_scrap"] = true,
	["grug_mobs:raw_fish"] = true, ["default:apple"] = true,
	["grug_mobs:zombie_flesh"] = true, ["default:papyrus"] = true,
}

-- Raw goods without a registry of their own: wild berries, and the
-- emberglass shards crystal creatures drop.
local GATHERED = {["default:blueberries"] = true,
	["grug_materials:emberglass_shard"] = true}

-- Tiers no registration carries: a shard is Emberglass, harvest tier 4.
local TIERS = {["grug_materials:emberglass_shard"] = 4}

-- Processed goods: the leather/bolt/wood/setting ladders, by group; bars come
-- from grug_materials.PROCESSED_MATERIALS.
local PROCESSED_GROUPS = {"grug_leather_grade", "grug_tailor_bolt",
	"grug_tailor_bundle", "grug_wood_grade", "grug_jewellery_setting",
	"grug_metal_rod"}

-- Free world materials of the first pass: anyone digs or chops them without
-- limit, so the first pass pays nothing for them and counts them 0 in a
-- recipe. Without this a vendor good made only from them (a wooden pick, a
-- stone brick, a glass vial) would keep its 5 % buy-back and turn digging
-- into money. The first pass keeps this set unchanged (ruling 2.2); the
-- second pass prices the bulk ones through BULK below, and the rest (dirt,
-- clay, snow, ice, flowers, dyes ...) stays worth 0.
local FREE_GROUPS = {"wood", "tree", "leaves", "sapling", "sand", "stone",
	"soil", "flower", "dye", "grug_natural", "grug_stratum"}
local FREE = {
	["default:cobble"] = true, ["default:mossycobble"] = true,
	["default:desert_cobble"] = true, ["default:sandstone"] = true,
	["default:desert_sandstone"] = true, ["default:silver_sandstone"] = true,
	["default:gravel"] = true, ["default:clay"] = true,
	["default:clay_lump"] = true, ["default:glass"] = true,
	["default:snow"] = true, ["default:snowblock"] = true,
	["default:ice"] = true,
}

-- The bulk table of the second pass (sell plan §3.2), in milli-copper: the
-- raw bulk materials and the plain building conversions made from them, so
-- no rule has to find conversions in the recipe graph. Sandstone is worth
-- exactly four sand (4 sand <-> 1 sandstone both ways); planks a quarter log,
-- rounded down. Stairs, slabs and walls are crafted goods.
local BULK = {}
for _, name in ipairs({"default:cobble", "default:mossycobble",
		"default:desert_cobble", "grug_materials:granite", "grug_materials:basalt",
		"grug_materials:slate", "default:stone", "default:stonebrick",
		"default:stone_block", "default:desert_stone", "default:desert_stonebrick",
		"default:desert_stone_block", "default:sand", "default:desert_sand",
		"default:silver_sand", "default:gravel"}) do
	BULK[name] = 20 -- 1c per 50
end
for _, name in ipairs({"default:sandstone", "default:sandstonebrick",
		"default:sandstone_block", "default:desert_sandstone",
		"default:desert_sandstone_brick", "default:desert_sandstone_block",
		"default:silver_sandstone", "default:silver_sandstone_brick",
		"default:silver_sandstone_block"}) do
	BULK[name] = 80 -- 1c per 20
end
BULK["default:cactus"] = 50 -- as a log
-- By group, first match: leaves and saplings 1c per 50, logs 1c per 20,
-- planks 1c per 99.
local BULK_GROUPS = {{"leaves", 20}, {"sapling", 20}, {"tree", 50}, {"wood", 12}}

-- Never sellable (sell plan §3.4): the Bag of Coins (economy.md §1), the
-- Fallen Crown, both Captain's Orders, and every soulbound or bound item
-- (the Claim Stone, ability items, the retired mount and boat items).
local NEVER = {["grug_money:bag_of_coins"] = true,
	["grug_mobs:throng_captains_orders"] = true,
	["grug_mobs:accord_captains_orders"] = true}
local NEVER_GROUPS = {"grug_soulbound", "grug_bound_skill", "grug_rare_trophy"}

-- Groups whose rating is the item's tier.
local TIER_GROUPS = {"grug_leather_grade", "grug_tailor_bolt", "grug_wood_grade",
	"grug_jewellery_setting", "grug_metal_rod"}

local catalogue -- id -> {kind, tier}
local resources -- raw/cut item -> resource row
local bars -- bar item -> processed row

local function load_registries()
	if catalogue then return end
	catalogue, resources, bars = {}, {}, {}
	local data = grug_mobs.read_data_json("items.json") or {}
	for _, row in ipairs(data.items or data) do
		if type(row) == "table" and type(row.id) == "string" then
			catalogue[row.id] = {kind = row.kind, tier = tonumber(row.tier)}
		end
	end
	for _, resource in ipairs(grug_materials.RESOURCES) do
		resources[resource.raw_item] = resource
		if resource.cut_item then resources[resource.cut_item] = resource end
	end
	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
		if material.kind == "bar" then bars[material.item] = material end
	end
end

local function valid_tier(tier)
	tier = tonumber(tier)
	if tier and tier >= 1 and tier <= 6 and tier % 1 == 0 then
		return tier
	end
	return nil
end

-- An item's own tier, or nil: its `_grug_tier` (or the TIERS table above), a
-- mined resource's harvest tier, a bar's tier, its catalogue tier, a grade
-- group, else the ingredient tier its profession declared. Used by the
-- payout and the shelf rule.
function grug_traders.item_tier(itemname)
	load_registries()
	local def = core.registered_items[itemname]
	if not def then return nil end
	local tier = valid_tier(def._grug_tier) or TIERS[itemname]
	if tier then return tier end
	local resource = resources[itemname]
	if resource then return valid_tier(resource.tier or resource.harvest_tier) end
	if bars[itemname] and bars[itemname].tier then return valid_tier(bars[itemname].tier) end
	local row = catalogue[itemname]
	if row and valid_tier(row.tier) then return valid_tier(row.tier) end
	for _, group in ipairs(TIER_GROUPS) do
		tier = valid_tier((def.groups or {})[group])
		if tier then return tier end
	end
	local jobs = rawget(_G, "grug_jobs")
	return jobs and jobs.ingredient_tier and valid_tier(jobs.ingredient_tier(itemname)) or nil
end

local function group(itemname, name)
	return core.get_item_group(itemname, name) > 0
end

-- Loot or gathered class of an item, or nil.
local function class_of(itemname, gathered)
	if TRASH[itemname] or group(itemname, "grug_trash_loot") then
		return "trash"
	end
	local resource = resources[itemname]
	if resource then
		return resource.gem and "gem" or "raw" -- ruling 8: six gem species
	end
	if gathered[itemname] or group(itemname, "grug_plant_item") or
			group(itemname, "food_fish_raw") then
		return "raw"
	end
	local row = catalogue[itemname]
	if row and (row.kind == "signature" or row.kind == "generic") then
		return row.kind
	end
	return nil
end

--
-- Recipes: the recipe registry (grug_jobs, every craft since Round 45), the
-- dual furnace and the engine's cooking recipes (furnaces).
--

local function split_item(str)
	local name, count = str:match("^(%S+)%s+(%d+)$")
	if name then return name, tonumber(count) end
	return str, 1
end

-- "example:item 2" adds the name twice: every input is one unit.
local function push_input(inputs, entry)
	local name, count = split_item(entry)
	for _ = 1, count do inputs[#inputs + 1] = name end
end

local station_recipes -- item -> recipes the engine does not hold
local recipe_cache = {} -- item -> every recipe that makes it

local function add_station_recipe(name, count, method, inputs)
	if #inputs == 0 then return end
	station_recipes[name] = station_recipes[name] or {}
	table.insert(station_recipes[name], {method = method, count = count, inputs = inputs})
end

local function load_station_recipes()
	station_recipes = {}
	local smelting = rawget(_G, "grug_smelting")
	for _, recipe in ipairs(smelting and smelting.RECIPES or {}) do
		local name, count = split_item(recipe.output)
		local inputs = {}
		for _, input in ipairs(recipe.inputs or {}) do push_input(inputs, input) end
		add_station_recipe(name, count, "dualfurn", inputs)
	end
	-- One input per unit: {group = "wood", n = 3} adds "group:wood" three times.
	local jobs = rawget(_G, "grug_jobs")
	for _, recipe in ipairs(jobs and jobs.recipes or {}) do
		local inputs = {}
		for _, entry in ipairs(recipe.ingredients) do
			local token = jobs.ingredient_token(entry)
			for _ = 1, entry.n do inputs[#inputs + 1] = token end
		end
		add_station_recipe(recipe.output, recipe.count, recipe.area, inputs)
	end
end

-- Every recipe that makes the item: {method, count, inputs = {names}}.
local function recipes_for(itemname)
	local list = recipe_cache[itemname]
	if list then return list end
	if not station_recipes then load_station_recipes() end
	list = {}
	for _, recipe in ipairs(station_recipes[itemname] or {}) do
		list[#list + 1] = recipe
	end
	-- The engine keeps only the furnace's cooking recipes; fuel and toolrepair
	-- make no item. The engine does not report cooking replacements (a
	-- returned bucket), so a recipe with one over-counts its inputs: that can
	-- only hide a loop, never invent one.
	for _, recipe in ipairs(core.get_all_craft_recipes(itemname) or {}) do
		local name, count = split_item(recipe.output or itemname)
		if recipe.method == "cooking" and name == itemname then
			-- pairs: empty slots are nil holes in `items`.
			local inputs = {}
			for _, entry in pairs(recipe.items or {}) do
				if type(entry) == "string" and entry ~= "" then push_input(inputs, entry) end
			end
			if #inputs > 0 then
				list[#list + 1] = {method = "cooking", count = count, inputs = inputs}
			end
		end
	end
	recipe_cache[itemname] = list
	return list
end
grug_traders.recipes_for = recipes_for

local members_cache = {}
local function group_members(groups)
	local key = table.concat(groups, ",")
	local cached = members_cache[key]
	if cached then return cached end
	cached = {}
	for name in pairs(core.registered_items) do
		local all = true
		for _, g in ipairs(groups) do
			if not group(name, g) then all = false break end
		end
		if all then cached[#cached + 1] = name end
	end
	table.sort(cached)
	members_cache[key] = cached
	return cached
end
grug_traders.group_members = group_members

--
-- Resolution
--

local payouts -- item -> copper (0 = known, not sellable); nil before load
local values -- item -> milli-copper, both passes (0 = known, not sellable)
local material -- item -> milli-copper before the halving (the loop audit)
local sold = {} -- item -> lowest vendor price, filled with the payouts

-- Lowest price any vendor asks for each item: the core stock, the profession
-- shelves and the T1 gear shelf.
local function sold_prices()
	local sold = {}
	local function note(item, price)
		if not sold[item] or price < sold[item] then sold[item] = price end
	end
	for _, entry in ipairs(grug_traders.stock) do note(entry.item, entry.price) end
	for _, shelf in pairs(grug_traders.profession_stock) do
		for _, entry in ipairs(shelf) do note(entry.item, entry.price) end
	end
	for _, entry in ipairs(grug_traders.bracket_stock(grug_traders.GEAR_BRACKET)) do
		note(entry.item, entry.price)
	end
	return sold
end

-- The reference price of every equippable no vendor sells (grug_gear's drop
-- pool of each tier): it pays the buy-back a sold base would.
local function reference_prices(sold)
	local reference = {}
	for bracket = 1, #grug_gear.BRACKETS do
		for _, item in ipairs(grug_gear.drop_pool[bracket]) do
			local price = grug_gear.get_price(item)
			if price and not sold[item] then reference[item] = price end
		end
	end
	return reference
end

-- The second pass's inputs (sell plan §3.2-§3.4): the bulk table, the storage
-- blocks, what keeps the first pass, the never list, every registered item.
local function second_pass_data(classified, reference)
	local bulk, storage, keep, never, candidates = {}, {}, {}, {}, {}
	local gear_price = rawget(grug_gear, "get_price")
	for itemname in pairs(core.registered_items) do
		candidates[itemname] = true
		if BULK[itemname] then
			bulk[itemname] = BULK[itemname]
		else
			for _, row in ipairs(BULK_GROUPS) do
				if group(itemname, row[1]) then
					bulk[itemname] = row[2]
					break
				end
			end
		end
		if classified[itemname] or sold[itemname] or reference[itemname] or
				(gear_price and gear_price(itemname)) then
			keep[itemname] = true
		end
		if NEVER[itemname] then never[itemname] = true end
		for _, name in ipairs(NEVER_GROUPS) do
			if group(itemname, name) then never[itemname] = true end
		end
	end
	-- The storage rows grug_smelting packs and unpacks: nine of the item make
	-- one block, unpacking is free, so a block pays nine times its item.
	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
		if core.registered_items[material.block_node] and
				core.registered_items[material.item] then
			storage[material.block_node] = {item = material.item, count = 9}
		end
	end
	return {first = payouts, bulk = bulk, storage = storage, keep = keep,
		never = never, candidates = candidates, recipes_for = recipes_for,
		group_members = group_members}
end

function grug_traders.resolve_prices()
	load_registries()
	local gathered = {}
	for item in pairs(GATHERED) do gathered[item] = true end
	local gathering = rawget(_G, "grug_gathering")
	if gathering then
		for _, row in ipairs(gathering.p9g_sources()) do gathered[row.raw_item] = true end
	end
	local classified, processed, free = {}, {}, {}
	for itemname in pairs(core.registered_items) do
		local class = class_of(itemname, gathered)
		if class then
			classified[itemname] = {class = class,
				tier = grug_traders.item_tier(itemname) or 1}
		end
		for _, name in ipairs(PROCESSED_GROUPS) do
			if group(itemname, name) then processed[itemname] = true end
		end
		if FREE[itemname] then free[itemname] = true end
		for _, name in ipairs(FREE_GROUPS) do
			if group(itemname, name) then free[itemname] = true end
		end
	end
	for item in pairs(bars) do
		if core.registered_items[item] then processed[item] = true end
	end
	sold = sold_prices()
	local reference = reference_prices(sold)
	payouts = rules.resolve({
		classified = classified,
		processed = processed,
		sold = sold,
		reference = reference,
		free = free,
		discounted = grug_traders.discounted_price,
		recipes_for = recipes_for,
		group_members = group_members,
	})
	values, material = rules.resolve_values(second_pass_data(classified, reference))
	return payouts
end

-- Value of an item in MILLI-COPPER, both passes; 0 = not sellable.
function grug_traders.sell_value(itemname)
	return values and values[itemname] or 0
end

-- Material value in MILLI-COPPER: a crafted good's value before its halving,
-- any other item's sell_value. What a recipe counts when it consumes it.
function grug_traders.material_value(itemname)
	return material and material[itemname] or 0
end

-- Vendor payout of one item that sells singly, in COPPER: today's payout, or
-- a new one of 1c or more. 0 = the vendor does not buy it singly: a lot good
-- (sell_offer) or not sellable.
function grug_traders.sell_price(itemname)
	local copper, lot = rules.lot_offer(grug_traders.sell_value(itemname))
	return lot == 1 and copper or 0
end

-- Vendor payout of one concrete stack's unit in COPPER: the item's payout
-- times its quality factor (a blue or gold drop sells above a Common one).
function grug_traders.stack_sell_price(stack)
	return rules.quality_payout(grug_traders.sell_price(stack:get_name()),
		stack:get_meta():get_int("grug_quality"))
end

-- What the vendor pays for a stack (or an item name): copper, lot. Lot 1 is
-- a single good at stack_sell_price (its quality included); a larger lot pays
-- `copper` per `lot` units (lot goods carry no quality); 0, nil = not sold.
function grug_traders.sell_offer(stack)
	if type(stack) == "string" then stack = ItemStack(stack) end
	local copper, lot = rules.lot_offer(grug_traders.sell_value(stack:get_name()))
	if lot == 1 then
		return grug_traders.stack_sell_price(stack), 1
	end
	return copper, lot
end

-- Whether the item has a value at all (a sum may count it, 0 included).
function grug_traders.price_known(itemname)
	return values ~= nil and values[itemname] ~= nil
end

-- Every item a vendor sells, sorted.
function grug_traders.sold_items()
	local list = {}
	for item in pairs(sold) do list[#list + 1] = item end
	table.sort(list)
	return list
end

-- The tier the shelf rule judges: a food by its own (raw) tier, which is why
-- the baker may sell a T1 melon that cooking uses at T4 (items_crafting.md
-- §3.7: raw and recipe tier differ on purpose); anything else by the higher of
-- its own tier and the ingredient tier a profession declared, so a T4
-- ingredient never passes as T1.
function grug_traders.shelf_tier(itemname)
	local tier = grug_traders.item_tier(itemname)
	if group(itemname, "grug_food") then return tier end
	local jobs = rawget(_G, "grug_jobs")
	local ingredient = jobs and jobs.ingredient_tier and valid_tier(jobs.ingredient_tier(itemname))
	if ingredient and (not tier or ingredient > tier) then return ingredient end
	return tier
end

-- Every item with a value above 0 (both passes, lot goods included), sorted.
function grug_traders.priced_items()
	local list = {}
	for item, value in pairs(values or {}) do
		if value > 0 then list[#list + 1] = item end
	end
	table.sort(list)
	return list
end
