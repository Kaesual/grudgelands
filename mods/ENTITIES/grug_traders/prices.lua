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
-- A concrete stack sells at its item's payout times its quality factor
-- (stack_sell_price: blue ×3, gold ×6).
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

-- Free world materials: anyone digs or chops them without limit, so traders
-- pay nothing for them and a recipe counts them 0. Without this a vendor good
-- made only from them (a wooden pick, a stone brick, a glass vial) would keep
-- its 5 % buy-back and turn digging into money.
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
-- Recipes: engine craft/cooking, the dual furnace and profession stations.
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
	local jobs = rawget(_G, "grug_jobs")
	for _, recipe in ipairs(jobs and jobs.recipes or {}) do
		-- In-place operations (enchants) return the item they consume.
		if not recipe.in_place and not recipe.operation then
			local output = ItemStack(recipe.output)
			add_station_recipe(output:get_name(), output:get_count(),
				recipe.station, recipe.flat_inputs or {})
		end
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
	-- Only input-consuming methods: fuel and toolrepair make no item. The
	-- engine does not report craft replacements (a returned bucket), so a
	-- recipe with one over-counts its inputs: that can only hide a loop,
	-- never invent one.
	for _, recipe in ipairs(core.get_all_craft_recipes(itemname) or {}) do
		local method = recipe.method or "normal"
		local name, count = split_item(recipe.output or itemname)
		if (method == "normal" or method == "cooking") and name == itemname then
			-- pairs: empty grid slots are nil holes in `items`.
			local inputs = {}
			for _, entry in pairs(recipe.items or {}) do
				if type(entry) == "string" and entry ~= "" then push_input(inputs, entry) end
			end
			if #inputs > 0 then
				list[#list + 1] = {method = method, count = count, inputs = inputs}
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
	payouts = rules.resolve({
		classified = classified,
		processed = processed,
		sold = sold,
		reference = reference_prices(sold),
		free = free,
		discounted = grug_traders.discounted_price,
		recipes_for = recipes_for,
		group_members = group_members,
	})
	return payouts
end

-- Vendor payout of an item in COPPER; 0 = the vendor does not buy it.
function grug_traders.sell_price(itemname)
	return payouts and payouts[itemname] or 0
end

-- Vendor payout of one concrete stack's unit in COPPER: the item's payout
-- times its quality factor (a blue or gold drop sells above a Common one).
function grug_traders.stack_sell_price(stack)
	return rules.quality_payout(grug_traders.sell_price(stack:get_name()),
		stack:get_meta():get_int("grug_quality"))
end

-- Whether the item has a value at all (a sum may count it, 0 included).
function grug_traders.price_known(itemname)
	return payouts ~= nil and payouts[itemname] ~= nil
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

-- Every item with a payout above 0, sorted.
function grug_traders.priced_items()
	local list = {}
	for item, copper in pairs(payouts or {}) do
		if copper > 0 then list[#list + 1] = item end
	end
	table.sort(list)
	return list
end
