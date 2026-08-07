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
-- The band is 1-5c and the ordering inside it mirrors the grug_mobs material
-- scale (items.lua: 1-3 vendor trash, 2-8 tier material):
--   mobs:meat_raw       2c  food, the single most common drop in the roster;
--                           the same price as our own grug_mobs:raw_fish
--   mobs:leather        2c  the vanilla hide, priced like our own
--                           grug_mobs:light_leather (2c) it sits next to in
--                           the wolf/stag/panther drop tables
--   default:iron_lump   3c  ore lump, one smelt below the ingot
--   default:steel_ingot 5c  top of the band ("a steel ingot may sit at the
--                           top of that band"), zombie drop at 1-in-10
--   default:diamond     5c  golem drop at 1-in-8. Capped at the band top ON
--                           PURPOSE: a diamond is a CRAFTING input, and the
--                           vendor floor must never out-pay using it
--                           (economy.md §4 "vendors are a floor, never a
--                           factory profit"). Flagged in the WP7 report.
--
grug_traders.set_price("mobs:meat_raw", 2)
grug_traders.set_price("mobs:leather", 2)
grug_traders.set_price("default:iron_lump", 3)
grug_traders.set_price("default:steel_ingot", 5)
grug_traders.set_price("default:diamond", 5)

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/potion.lua")
dofile(modpath .. "/stock.lua")
dofile(modpath .. "/vendors.lua")
dofile(modpath .. "/trade.lua")

--
-- Startup audits
--
-- Two invariants that are cheap to check once and expensive to notice late.
-- Both are SILENT when everything is in order.
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
end)
