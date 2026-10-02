-- Round 29 Lane E1 portable test (LuaJIT): the vendor payout rules and the
-- shelves (economy-vendor-plan.md §2-§3).
--
-- Loads the REAL grug_traders/price_rules.lua (pure) and the real
-- grug_traders/stock.lua under a minimal `core` stub. Checks:
--   1. the formula: tier factors, class values, round half up, minimum 1c;
--   2. the 5 % ceiling buy-back and its "never at or above the discounted
--      price" floor (thread 1c is not sellable);
--   3. resolve(): processed goods = their cheapest recipe (bars through the
--      dual furnace, a leather grade capped below its loot formula), sold
--      goods capped by their recipe (100 arrows from one bar), a group input
--      by its cheapest known member, an unknown input makes its recipe
--      unknown, a vendor supply counts 0, a pack/unpack cycle is cut;
--   4. loop_findings(): an overpriced loot output is reported, break-even is
--      allowed (ruling 5's ≤), unknown inputs are not judged;
--   5. shelf_findings(): enchant inputs and materials above T1 fail;
--   6. the shipped shelves are exactly the economy plan's §2.3 table.
--
-- Usage (repo root): luajit tools/r29_e1/portable_test.lua [ROOT]
-- Prints "R29 E1 PORTABLE PASS checks=<n>", or lists the failures and errors.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local rules = dofile(ROOT .. "/mods/ENTITIES/grug_traders/price_rules.lua")

------------------------------------------------------------------------------
-- 1. The formula.
------------------------------------------------------------------------------
eq(#rules.TIER_FACTOR, 6, "six tier factors")
local factors = {1, 2.6, 6.4, 16, 40, 100}
for tier = 1, 6 do
	eq(rules.TIER_FACTOR[tier], factors[tier], "tier factor T" .. tier)
end
for _, class in ipairs({"trash", "raw", "generic", "signature", "gem"}) do
	check(type(rules.CLASS_VALUE[class]) == "number" and rules.CLASS_VALUE[class] > 0,
		"class value " .. class)
end
-- The cases below follow from the class values; recompute them so the test
-- survives a later tuning and still pins the rounding.
local function expected(class, tier)
	return math.max(1, math.floor(rules.CLASS_VALUE[class] * factors[tier] + 0.5))
end
for _, class in ipairs({"trash", "raw", "generic", "signature", "gem"}) do
	for tier = 1, 6 do
		eq(rules.payout(class, tier), expected(class, tier), class .. " T" .. tier)
	end
end
-- Pinned values of the shipped class table (calibration record).
eq(rules.payout("trash", 1), 1, "trash T1 = 1c")
eq(rules.payout("trash", 2), 3, "trash T2 = 2.6 rounds to 3c")
eq(rules.payout("raw", 3), 6, "raw T3 (silver) = 6.4 rounds to 6c")
eq(rules.payout("generic", 3), 13, "generic T3 = 12.8 rounds to 13c")
eq(rules.payout("signature", 1), 7, "signature T1 = 7c")
eq(rules.payout("signature", 6), 700, "signature T6 = 7s")
eq(rules.payout("gem", 4), 64, "gem T4 = 64c")
eq(rules.payout("nope", 1), 0, "unknown class pays 0")
eq(rules.payout("trash", 7), 0, "tier outside 1..6 pays 0")

------------------------------------------------------------------------------
-- 2. Buy-back.
------------------------------------------------------------------------------
local function discounted(price) return math.max(1, math.floor(price * 0.9)) end
eq(rules.buyback(25, discounted(25)), 2, "T1 weapon 25c buys back at 2c")
eq(rules.buyback(2500, discounted(2500)), 125, "T6 weapon 25s buys back at 1s25c")
eq(rules.buyback(1250, discounted(1250)), 63, "12s50c rounds up to 63c")
eq(rules.buyback(8, discounted(8)), 1, "potion 8c buys back at 1c")
eq(rules.buyback(1, discounted(1)), 0, "thread 1c is not sellable")
eq(rules.buyback(2, discounted(2)), 0, "a 2c supply is not sellable")
eq(rules.buyback(3, discounted(3)), 1, "a 3c supply buys back at 1c")

------------------------------------------------------------------------------
-- 3. resolve().
------------------------------------------------------------------------------
local RECIPES = {
	["t:copper_bar"] = {{method = "cooking", count = 1, inputs = {"t:copper_lump"}},
		-- unpacking a block nobody prices: an unknown input, not a free bar
		{method = "normal", count = 9, inputs = {"t:copper_block"}}},
	["t:tin_bar"] = {{method = "cooking", count = 1, inputs = {"t:tin_lump"}}},
	["t:bronze_bar"] = {{method = "dualfurn", count = 1,
		inputs = {"t:copper_bar", "t:tin_bar"}}},
	["t:silver_bar"] = {{method = "cooking", count = 1, inputs = {"t:silver_lump"}}},
	["t:silversteel_bar"] = {{method = "dualfurn", count = 1,
		inputs = {"t:bronze_bar", "t:silver_bar"}}},
	-- a processed item made in pairs pays half its inputs, rounded down
	["t:rod"] = {{method = "normal", count = 4, inputs = {"t:silversteel_bar", "t:silversteel_bar"}}},
	["t:light_leather"] = {{method = "normal", count = 1, inputs = {"t:hide", "t:thread"}}},
	["t:heavy_leather"] = {{method = "normal", count = 1, inputs = {"t:light_leather", "t:thread"}}},
	["t:arrow"] = {{method = "normal", count = 100,
		inputs = {"t:bronze_bar", "group:stick", "group:stick"}}},
	["t:dagger"] = {{method = "normal", count = 1, inputs = {"t:bronze_bar", "group:stick"}}},
	["t:shield"] = {{method = "normal", count = 1, inputs = {"t:bronze_bar", "group:wood"}}},
	-- a pack/unpack cycle between two processed goods
	["t:gem_block"] = {{method = "normal", count = 1, inputs = {"t:cut_gem", "t:cut_gem",
		"t:cut_gem", "t:cut_gem", "t:cut_gem", "t:cut_gem", "t:cut_gem", "t:cut_gem", "t:cut_gem"}}},
	["t:cut_gem"] = {{method = "normal", count = 9, inputs = {"t:gem_block"}},
		{method = "normal", count = 1, inputs = {"t:rough_gem"}}},
}
local GROUPS = {stick = {"t:stick", "t:fancy_stick"}, wood = {"t:planks"}}
local data = {
	classified = {
		["t:copper_lump"] = {class = "raw", tier = 1},
		["t:tin_lump"] = {class = "raw", tier = 1},
		["t:silver_lump"] = {class = "raw", tier = 3},
		["t:hide"] = {class = "generic", tier = 1},
		["t:light_leather"] = {class = "generic", tier = 1},
		["t:heavy_leather"] = {class = "generic", tier = 3},
		["t:stick"] = {class = "trash", tier = 1},
		["t:fancy_stick"] = {class = "signature", tier = 2},
		["t:rough_gem"] = {class = "gem", tier = 4},
		["t:cut_gem"] = {class = "gem", tier = 4},
	},
	processed = {["t:copper_bar"] = true, ["t:tin_bar"] = true,
		["t:bronze_bar"] = true, ["t:silver_bar"] = true,
		["t:silversteel_bar"] = true, ["t:rod"] = true,
		["t:light_leather"] = true, ["t:heavy_leather"] = true,
		["t:gem_block"] = true, ["t:cut_gem"] = true, ["t:no_recipe"] = true},
	sold = {["t:thread"] = 1, ["t:arrow"] = 3, ["t:dagger"] = 400,
		["t:shield"] = 1250, ["t:potion"] = 8, ["t:hide"] = 8},
	discounted = discounted,
	recipes_for = function(item) return RECIPES[item] or {} end,
	group_members = function(groups) return GROUPS[groups[1]] or {} end,
}
local v = rules.resolve(data)
local raw1, raw3 = expected("raw", 1), expected("raw", 3)
eq(v["t:copper_bar"], raw1, "bar = its lump (the block route is unknown, not free)")
eq(v["t:bronze_bar"], 2 * raw1, "alloy = both bars")
eq(v["t:silversteel_bar"], 2 * raw1 + raw3, "alloy chain")
eq(v["t:rod"], math.floor(2 * (2 * raw1 + raw3) / 4), "4 rods from 2 bars, rounded down")
eq(v["t:thread"], 0, "thread: known, not sellable")
eq(v["t:light_leather"], expected("generic", 1),
	"leather grade = hide + thread (0), equal to its formula")
eq(v["t:heavy_leather"], expected("generic", 1),
	"a refined grade is capped by its recipe below its loot formula (ruling 5)")
check(expected("generic", 3) > v["t:heavy_leather"], "the cap is below the T3 formula")
eq(v["t:hide"], expected("generic", 1), "a looted good on a shelf pays its formula, not 5 %")
eq(v["t:arrow"], 0, "100 arrows from one bar and two sticks: not sellable")
eq(v["t:dagger"], 2 * raw1 + expected("trash", 1),
	"a sold weapon is capped by its recipe; the group counts its cheapest member")
eq(v["t:shield"], rules.buyback(1250, discounted(1250)),
	"a recipe with an unknown group input (wood) does not cap")
eq(v["t:potion"], 1, "sold without recipe: 5 % buy-back")
eq(v["t:cut_gem"], expected("gem", 4), "cut gem = its formula (cycle cut, rough route)")
eq(v["t:gem_block"], 9 * expected("gem", 4), "a storage block = nine of its unit")
eq(v["t:no_recipe"], nil, "a processed good without a usable recipe stays unknown")
eq(v["t:planks"], nil, "an unclassified world material stays unknown")

------------------------------------------------------------------------------
-- 4. loop_findings().
------------------------------------------------------------------------------
local prices = {["t:a"] = 5, ["t:b"] = 3, ["t:out"] = 9, ["t:even"] = 8,
	["t:free"] = 0, ["t:g1"] = 2, ["t:g2"] = 6, ["t:grouped"] = 4}
local LOOP_RECIPES = {
	["t:out"] = {{method = "normal", count = 1, inputs = {"t:a", "t:b"}}},
	["t:even"] = {{method = "normal", count = 1, inputs = {"t:a", "t:b"}}},
	["t:grouped"] = {{method = "normal", count = 1, inputs = {"group:g", "t:free"}},
		{method = "normal", count = 1, inputs = {"t:unknown", "t:free"}}},
}
local findings = rules.loop_findings({"t:out", "t:even", "t:grouped"},
	function(item) return LOOP_RECIPES[item] or {} end,
	function(item) return prices[item] or 0 end,
	function(item) return prices[item] ~= nil end,
	function(groups) return groups[1] == "g" and {"t:g1", "t:g2"} or {} end)
eq(#findings, 2, "two loops: 9c from 8c, and 4c from the cheapest group member 2c")
check(findings[1] and findings[1]:find("t:grouped", 1, true) ~= nil, "group judged by its cheapest member")
check(findings[2] and findings[2]:find("t:out", 1, true) ~= nil, "overpriced output reported")

------------------------------------------------------------------------------
-- 5. shelf_findings().
------------------------------------------------------------------------------
local tiers = {["t:t1"] = 1, ["t:t2"] = 2, ["t:enchant"] = 1}
local failed = rules.shelf_findings({
	{kind = "core", item = "t:t1"}, {kind = "smith", item = "t:t2"},
	{kind = "butcher", item = "t:enchant"}, {kind = "mason", item = "t:untiered"},
}, {["t:enchant"] = true}, function(item) return tiers[item] end)
eq(#failed, 2, "two shelf entries break the vendor rule")
eq(failed[1] and failed[1].item, "t:t2", "a T2 material fails")
eq(failed[1] and failed[1].reason, "tier 2 material", "its reason")
eq(failed[2] and failed[2].reason, "enchant input", "an enchant input fails")

------------------------------------------------------------------------------
-- 6. The shipped shelves (economy-vendor-plan.md §2.3).
------------------------------------------------------------------------------
core = {
	register_on_mods_loaded = function() end,
	log = function() end,
}
grug_traders = {}
dofile(ROOT .. "/mods/ENTITIES/grug_traders/stock.lua")
local function items(list)
	local out = {}
	for _, entry in ipairs(list) do out[#out + 1] = entry.item end
	table.sort(out)
	return table.concat(out, " ")
end
local function sorted(list)
	table.sort(list)
	return table.concat(list, " ")
end
eq(items(grug_traders.stock), sorted({"grug_inventory:bag_small",
	"grug_traders:potion_healing_weak", "default:torch", "grug_gear:arrow",
	"grug_materials:pick_wood", "grug_materials:shovel_wood", "grug_materials:axe_wood",
	"grug_materials:pick_stone", "grug_materials:shovel_stone",
	"grug_materials:axe_stone", "grug_materials:pick_bronze"}),
	"core stock (thread, parchment and vial join from their own mods)")
local SHELVES = {
	butcher = {"mobs:meat_raw", "mobs:meat", "mobs:leather", "grug_mobs:light_leather"},
	fishmonger = {"grug_mobs:raw_fish"},
	baker = {"grug_gathering:corn", "grug_gathering:potato", "grug_gathering:melon",
		"grug_cooking:bread"},
	tailor = {"grug_mobs:linen_scrap", "wool:white", "wool:brown"},
	smith = {"grug_materials:bronze_bar", "grug_materials:pick_bronze",
		"grug_materials:axe_bronze", "grug_materials:shovel_bronze"},
	armourer = {"grug_materials:bronze_bar"},
	tanner = {"mobs:leather", "grug_mobs:light_leather"},
	bowyer = {"grug_gear:arrow", "default:stick", "grug_mobs:feather"},
	brewer = {"grug_traders:potion_healing_weak", "default:apple"},
	herbalist = {"grug_traders:potion_healing_weak"},
	embalmer = {"grug_mobs:bone", "grug_decor:xdecor_candle", "grug_mobs:linen_scrap",
		"grug_mobs:zombie_flesh"},
	mason = {"default:cobble", "default:gravel", "default:clay_brick",
		"default:stonebrick", "default:sandstonebrick", "default:stone_block"},
}
local kinds = 0
for kind in pairs(grug_traders.profession_stock) do
	kinds = kinds + 1
	check(SHELVES[kind] ~= nil, "unexpected shelf " .. kind)
end
eq(kinds, 12, "twelve profession shelves")
for kind, expected_items in pairs(SHELVES) do
	eq(items(grug_traders.profession_stock[kind] or {}), sorted(expected_items), kind .. " shelf")
end
-- A supply registered for every vendor reaches every shelf.
grug_traders.register_all_vendor_stock({item = "x:vial", price = 3})
for kind, shelf in pairs(grug_traders.profession_stock) do
	check(shelf[#shelf].item == "x:vial", "all-vendor supply on " .. kind)
end
eq(grug_traders.stock[#grug_traders.stock].item, "x:vial", "all-vendor supply in the core stock")

if failures > 0 then
	error(("R29 E1 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R29 E1 PORTABLE PASS checks=%d"):format(checks))
