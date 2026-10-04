-- Traders (docs/design/economy.md §1-§3, items_crafting.md §3.6/§3.7/§3.8/
-- §8.1/§8.2, world.md §7, professions.md §4).
--
-- WHAT LIVES WHERE
--   init.lua    the startup audits ("traders buy EVERY mob drop", no
--               buy-back loop, no craft loop)
--   prices.lua  the one price module: every vendor payout (price_rules.lua
--               holds its pure rules)
--   potion.lua  the weak healing potion and the shared instant-potion cooldown
--   stock.lua   the level-independent core stock, the T1 gear shelf and the
--               profession shelves
--   vendors.lua the eight vendor entities, their access rules and their
--               deterministic placement at the six race capitals
--   trade.lua   the trade formspec (buy/sell) and its re-validation
--
-- Money is NEVER computed here: every balance change goes through
-- grug_money.take/add (economy.md §1, one integer in copper in player meta).

grug_traders = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/prices.lua")
dofile(modpath .. "/potion.lua")
dofile(modpath .. "/stock.lua")
dofile(modpath .. "/vendors.lua")
dofile(modpath .. "/trade.lua")

--
-- Startup audits
--
-- Three invariants that are cheap to check once and expensive to notice late.
-- None of them emits a warning/error finding when everything is in
-- order; one informational action line (the function-drop audit count
-- below) always prints.
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

-- The real no-buyback-loop boundary, public so the focused stock KAT can
-- exercise the same complete stock/catalog walk used at server startup.
function grug_traders.audit_sell_buy_prices()
	local failures = {}
	local function check(itemname, price)
		local discounted = grug_traders.discounted_price(price)
		local buyback = grug_traders.sell_price(itemname)
		if buyback >= discounted then
			local message = "[grug_traders] MONEY LOOP: '" .. itemname ..
				"' sells for " .. discounted .. "c (discounted) but buys back " ..
				"at " .. buyback .. "c"
			failures[#failures + 1] = message
			core.log("error", message)
		end
	end
	for _, entry in ipairs(grug_traders.stock) do
		check(entry.item, entry.price)
	end
	for _, shelf in pairs(grug_traders.profession_stock) do
		for _, entry in ipairs(shelf) do
			check(entry.item, entry.price)
		end
	end
	for _, entry in ipairs(grug_traders.bracket_stock(grug_traders.GEAR_BRACKET)) do
		check(entry.item, entry.price)
	end
	return failures
end

core.register_on_mods_loaded(function()
	-- Every payout first: the audits below judge the resolved prices.
	grug_traders.resolve_prices()

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

	-- Round 28 family drop tables by level band (grug_mobs/subtypes.lua):
	-- they replace a mob's static drops, so their items are mob drops too.
	for itemname, families in pairs(grug_mobs.band_drop_items()) do
		for family in pairs(families) do
			note(itemname, "drops.json " .. family)
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
			") — give it a loot class in grug_traders/prices.lua; traders must " ..
			"buy every mob drop (economy.md §3)")
	end

	--
	-- 2. No money printer. Every item a vendor SELLS must cost strictly more
	-- than the vendor pays to buy it back, INCLUDING the 10% same-race
	-- discount (world.md §7) — otherwise buy-then-sell is an income stream.
	-- The 5% buy-back guarantees it for what has no loot class; a looted or
	-- gathered good on a shelf pays its formula, so its shelf price has to
	-- stay above that.
	--
	grug_traders.audit_sell_buy_prices()

	--
	-- 3. No CRAFT loop either (ruling 5): an output pays at most what its
	-- consumed inputs pay. Check 2 covers buy-then-sell at one vendor; this
	-- one covers buy/loot-then-CRAFT-then-sell over every engine recipe, the
	-- dual furnace and the profession stations. Processed goods and vendor
	-- goods are capped by their cheapest recipe when they are priced, so
	-- this mostly guards loot and gathered goods that a recipe can also make.
	-- A recipe is judged only when every input is known (a group by its
	-- cheapest known member): an unknown input is not a free lunch.
	--
	local findings = grug_traders.price_rules.loop_findings(
		grug_traders.priced_items(), grug_traders.recipes_for,
		grug_traders.sell_price, grug_traders.price_known,
		grug_traders.group_members)
	for _, message in ipairs(findings) do
		core.log("error", "[grug_traders] CRAFT LOOP: " .. message ..
			" — ruling 5 of economy-vendor-plan.md")
	end
	-- A sold good keeps its 5% buy-back only because no recipe that makes it
	-- could be judged: one of its inputs has no value. If that input is a
	-- free world material, it belongs in prices.lua's free set.
	for _, item in ipairs(grug_traders.price_rules.unjudged_sold(
			grug_traders.sold_items(), grug_traders.recipes_for,
			grug_traders.sell_price, grug_traders.price_known,
			grug_traders.group_members)) do
		core.log("warning", "[grug_traders] '" .. item .. "' is sold and pays " ..
			grug_traders.sell_price(item) .. "c back, but no recipe that makes it " ..
			"can be judged (an input has no value) — a free input belongs in " ..
			"prices.lua's free set")
	end
end)
