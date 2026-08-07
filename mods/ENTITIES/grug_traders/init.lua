-- Traders (docs/design/economy.md §1-§3, items_crafting.md §3.6/§3.7/§3.8/
-- §8.1/§8.2, world.md §7, professions.md §4).
--
-- WHAT LIVES WHERE
--   init.lua    price resolution ("traders buy EVERY mob drop") + the startup
--               audit that proves that guarantee
--   potion.lua  the weak healing potion and the shared instant-potion cooldown
--   stock.lua   the level-independent core stock, the six bracket catalogs and
--               the hourly rotation
--   vendors.lua the eight vendor entities, their access rules and their
--               deterministic placement at the six race capitals
--   trade.lua   the trade formspec (buy/sell) and its re-validation
--
-- Money is NEVER computed here: every balance change goes through
-- grug_money.take/add (economy.md §1, one integer in copper in player meta).

grug_traders = {}

--
-- Price resolution
--
-- economy.md §3: "traders buy EVERY mob drop". The buy-back price of an item
-- normally lives in its own definition (`_grug_sell_price`, set by grug_mobs
-- and grug_gear), but several drops are FOREIGN items whose definitions we do
-- not own (vendored `default:` / `mobs:`) — overriding a foreign item just to
-- add one field would be a patch in someone else's mod. So this mod keeps an
-- override table in front of the def lookup.
--
-- Resolution order: override table -> item def `_grug_sell_price` -> 0.
-- 0 means "not sellable" and is what every caller checks.
--

local price_override = {}

-- Override the vendor buy-back price of an item, in COPPER. Use this for
-- items whose definition we must not touch; our own items carry
-- `_grug_sell_price` in their def instead. copper <= 0 clears the override.
function grug_traders.set_price(itemname, copper)
	if type(itemname) ~= "string" or itemname == "" then
		return
	end
	copper = tonumber(copper)
	if not copper or copper ~= copper or copper <= 0 then
		price_override[itemname] = nil
		return
	end
	price_override[itemname] = math.floor(copper)
end

-- Vendor buy-back price of an item in COPPER; 0 = the vendor does not buy it.
function grug_traders.sell_price(itemname)
	if type(itemname) ~= "string" or itemname == "" then
		return 0
	end
	local override = price_override[itemname]
	if override then
		return override
	end
	local def = core.registered_items[itemname]
	local price = def and def._grug_sell_price
	price = tonumber(price)
	if not price or price ~= price or price <= 0 then
		return 0
	end
	return math.floor(price)
end

--
-- Foreign mob drops (items_crafting.md §8.1: "Herbs/materials sold to
-- vendors: 1-3c each" — the floor band; the real market is player trade).
-- Collected by walking every `drops` table in mods/ENTITIES/grug_mobs; the
-- audit at the bottom of this file re-proves the list at every start.
--
-- EVERY price below stays inside §8.1's 1-3c band; the ordering inside it
-- mirrors the grug_mobs material scale (items.lua: 1-3 vendor trash):
--   mobs:meat_raw       2c  food, the single most common drop in the roster;
--                           the same price as our own grug_mobs:raw_fish
--   mobs:leather        2c  the vanilla hide, priced like our own
--                           grug_mobs:light_leather (2c) it sits next to in
--                           the wolf/stag/panther drop tables
--   default:iron_lump   3c  ore lump, top of the band
--   default:steel_ingot 3c  zombie drop at 1-in-10. NOT a copper above the
--                           lump: default registers a `cooking` recipe
--                           lump -> ingot (mods/BASE/default/craftitems.lua),
--                           so any premium on the ingot would be free copper
--                           per smelt. items_crafting.md §3.8: "vendor value
--                           of a crafted item < summed vendor value of its
--                           ingredients -- vendors are a floor, never a
--                           factory profit". Audit 3 below enforces exactly
--                           that, for every priced item and every recipe.
--   default:diamond     3c  golem drop at 1-in-8. Capped at the band top ON
--                           PURPOSE: a diamond is a CRAFTING input, and the
--                           vendor floor must never out-pay using it (§3.8
--                           again).
--
grug_traders.set_price("mobs:meat_raw", 2)
grug_traders.set_price("mobs:leather", 2)
grug_traders.set_price("default:iron_lump", 3)
grug_traders.set_price("default:steel_ingot", 3)
grug_traders.set_price("default:diamond", 3)

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/potion.lua")
dofile(modpath .. "/stock.lua")
dofile(modpath .. "/vendors.lua")
dofile(modpath .. "/trade.lua")

--
-- Startup audits
--
-- Three invariants that are cheap to check once and expensive to notice late.
-- All of them are SILENT when everything is in order.
--

-- Drop items a `drops` FUNCTION can return. Function-form drop tables cannot
-- be walked statically (they are called with the death position), so the
-- items they can produce are listed here by hand and audited like any static
-- table. One entry today: grug_mobs/bandit.lua.
local FUNCTION_DROPS = {
	["grug_mobs:bandit"] = {
		"grug_mobs:linen_cloth", -- inner camps
		"grug_mobs:heavy_cloth", -- outer camps
		"grug_mobs:stolen_purse",
	},
}

core.register_on_mods_loaded(function()
	--
	-- 1. "Traders buy EVERY mob drop" (economy.md §3).
	--
	local unpriced = {} -- item name -> list of entity names
	local order = {}
	local function note(itemname, entity_name)
		if grug_traders.sell_price(itemname) > 0 then
			return
		end
		if not unpriced[itemname] then
			unpriced[itemname] = {}
			order[#order + 1] = itemname
		end
		table.insert(unpriced[itemname], entity_name)
	end

	local function_forms = {}
	for name, def in pairs(core.registered_entities) do
		local drops = def.drops
		if type(drops) == "function" then
			function_forms[#function_forms + 1] = name
			for _, itemname in ipairs(FUNCTION_DROPS[name] or {}) do
				note(itemname, name)
			end
		elseif type(drops) == "table" then
			for _, entry in ipairs(drops) do
				if type(entry) == "table" and type(entry.name) == "string" then
					note(entry.name, name)
				end
			end
		end
	end

	if #function_forms > 0 then
		-- Logged ONCE, not per mob: this is the known static-analysis blind
		-- spot, not a defect. The items those functions return are covered by
		-- FUNCTION_DROPS above.
		table.sort(function_forms)
		core.log("action", "[grug_traders] drop audit: " .. #function_forms ..
			" mob(s) use a `drops` FUNCTION and cannot be walked statically (" ..
			table.concat(function_forms, ", ") ..
			"); their items are audited from the hardcoded FUNCTION_DROPS list")
	end

	table.sort(order)
	for _, itemname in ipairs(order) do
		core.log("warning", "[grug_traders] no vendor price for dropped item '" ..
			itemname .. "' (dropped by " ..
			table.concat(unpriced[itemname], ", ") ..
			") — add a _grug_sell_price to its def or a grug_traders.set_price " ..
			"override; traders must buy every mob drop (economy.md §3)")
	end

	--
	-- 2. No money printer. Every item a vendor SELLS must cost strictly more
	-- than the vendor pays to buy it back, INCLUDING the 10% same-race
	-- discount (world.md §7) — otherwise buy-then-sell is an income stream.
	-- grug_gear's 25% buy-back already guarantees it for the whole bracket
	-- catalog; this loop is what turns "already guarantees" into a fact that
	-- fails loudly if a price is ever edited.
	--
	local function check(itemname, price)
		local discounted = grug_traders.discounted_price(price)
		local buyback = grug_traders.sell_price(itemname)
		if buyback >= discounted then
			core.log("error", "[grug_traders] MONEY LOOP: '" .. itemname ..
				"' sells for " .. discounted .. "c (discounted) but buys back " ..
				"at " .. buyback .. "c")
		end
	end
	for _, entry in ipairs(grug_traders.stock) do
		check(entry.item, entry.price)
	end
	for bracket = 1, #grug_gear.BRACKETS do
		for _, itemname in ipairs(grug_gear.catalog[bracket].all) do
			check(itemname, grug_gear.get_price(itemname))
		end
	end

	--
	-- 3. No CRAFT loop either. items_crafting.md §3.8: "vendor value of a
	-- crafted item < summed vendor value of its ingredients — vendors are a
	-- floor, never a factory profit". Check 2 above only covers buy-then-sell
	-- at one vendor; this one covers buy/loot-then-CRAFT-then-sell, which is
	-- the same money printer with one extra step (the real case: pricing a
	-- steel ingot above the iron lump it is smelted from).
	--
	-- For every item that has a vendor price we walk every registered recipe
	-- producing it. A recipe is only judged when EVERY input resolves to a
	-- price — an unpriced input is not a loop we can judge, it is an unknown.
	--
	-- Limits, on purpose:
	--   * only input-CONSUMING methods are judged. "fuel" and "toolrepair"
	--     produce no output item (they are indexed under the empty output
	--     name and never show up here), and neither burns an item into
	--     sellable goods.
	--   * `core.get_all_craft_recipes` does not report craft REPLACEMENTS
	--     (the bucket/vessel that comes back out), so a recipe with
	--     replacements over-counts its inputs — that direction can only
	--     produce a false SILENCE about a too-cheap output, never a false
	--     alarm about a money loop.
	--
	local CONSUMING_METHODS = {normal = true, cooking = true}

	-- "default:diamond 9" -> "default:diamond", 9. Recipe INPUTS are plain
	-- item names, but outputs carry a count, and the same parse is correct
	-- for both.
	local function split_item(str)
		local name, count = str:match("^(%S+)%s+(%d+)$")
		if name then
			return name, tonumber(count)
		end
		return str, 1
	end

	local function craft_check(itemname)
		local recipes = core.get_all_craft_recipes(itemname)
		if not recipes then
			return
		end
		for _, recipe in ipairs(recipes) do
			if type(recipe) == "table" and
					CONSUMING_METHODS[recipe.method or "normal"] then
				local out_name, out_count = split_item(recipe.output or itemname)
				local out_price = grug_traders.sell_price(out_name) * out_count
				-- pairs, not ipairs: empty grid slots are nil HOLES in
				-- `items` (lua_api.md "Empty ingredients ... are represented
				-- as nil"), and ipairs would stop at the first one and
				-- undercount a shaped recipe into a false alarm.
				local input_total, priced = 0, true
				local used = {} -- names only, for the message (never concat
				                -- `items` itself: the holes would error)
				for _, entry in pairs(recipe.items or {}) do
					if type(entry) == "string" and entry ~= "" then
						local in_name, in_count = split_item(entry)
						local in_price = grug_traders.sell_price(in_name)
						if in_price <= 0 then
							-- Also the "group:wood" case: a group never has a
							-- price of its own.
							priced = false
							break
						end
						input_total = input_total + in_price * in_count
						used[#used + 1] = entry
					end
				end
				-- #used > 0: a recipe shape we could not read a single input
				-- from is an unknown, not a free lunch.
				if priced and #used > 0 and out_price > input_total then
					core.log("error", "[grug_traders] CRAFT LOOP: '" .. out_name ..
						"' x" .. out_count .. " is worth " .. out_price ..
						"c at the vendor but its " .. (recipe.method or "normal") ..
						" recipe consumes only " .. input_total ..
						"c worth of priced inputs (" ..
						table.concat(used, ", ") ..
						") — items_crafting.md §3.8 anti-loop rule")
				end
			end
		end
	end

	-- Every item with a vendor price: the def field covers our own items, the
	-- override table the foreign ones (and both are deduped).
	local seen_priced, priced_order = {}, {}
	local function note_priced(itemname)
		if not seen_priced[itemname] and grug_traders.sell_price(itemname) > 0 then
			seen_priced[itemname] = true
			priced_order[#priced_order + 1] = itemname
		end
	end
	for itemname in pairs(core.registered_items) do
		note_priced(itemname)
	end
	for itemname in pairs(price_override) do
		note_priced(itemname)
	end
	table.sort(priced_order) -- deterministic log order
	for _, itemname in ipairs(priced_order) do
		craft_check(itemname)
	end
end)
