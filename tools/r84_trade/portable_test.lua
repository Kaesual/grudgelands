-- Round 84 lane TRADE portable fixture (LuaJIT): quantity buttons on every
-- trade row (round84-plan.md ruling 2, defaults 20 and 21, §3.1), on the
-- whole game's registrations (the Round 57 game harness, tools/r84_trade/
-- world.lua) with fake players.
--
--   luajit tools/r84_trade/portable_test.lua REPO
--
-- A. The rule (grug_traders.quantities): gear 1; a potion 1 / 5 / 20; arrows
--    1 / 5 / 20 / Stack 100; a 99-stack 1 / 5 / 20 / Stack 99; 13 potions in
--    a slot 1 / 5 / Stack 13; a full slot without Stack; lots below one, one,
--    several; and the real items' stack sizes.
-- B. Buying: each row's buttons by its item; 20 arrows paid and delivered
--    as one; the kinship discount per item; an unaffordable amount greyed
--    and refused whole; a full and a nearly full inventory greyed and
--    refused with nothing paid; a changed shelf refused; forged keys and
--    amounts buy nothing; the gear tab's rows carry one button.
-- C. Selling: 13 potions 1 / 5 / Stack 13, Stack sells the slot; 20
--    potions 1 / 5 / 20; a slot changed since the render is refused; a lot
--    good's one lot and All, All gone at one lot; below one lot no button.
-- D. The Trade-in: one lot and All, by the lot's count.
-- E. The Stonewright: one conversion and All, by what it makes.
-- F. The reputation page: the buy form; five bought for five prices; an
--    unaffordable amount greyed and refused; grug_guild.buy's counts.
-- G. Fix round 1: a click from a form drawn before the last render (a
--    double click: Sell's Stack, Buy, Trade-in, Stonewright, reputation)
--    acts on nothing, its quit is dropped, a fresh click and a tab work.
--
-- Prints "R84 TRADE PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end

local W = dofile(repo .. "/tools/r84_trade/world.lua")(repo)
for _, line in ipairs(W.game.failures) do
	check(not line:find("grug_traders", 1, true) and not line:find("grug_guild", 1, true),
		"the mods load in the harness: " .. line)
end
check(W.prices_ok, "the prices resolve: " .. tostring(W.prices_err))
local C = grug_guild.catalog
local function has(text) local fs = W.shown() return fs ~= nil and fs:find(text, 1, true) ~= nil end
local GREY = "\27(c@#8a8a8a)"
local function greyed(text) return has(core.formspec_escape(GREY .. text .. "\27(c@#fff)")) end

------------------------------------------------------------------------------
-- A. The rule.
------------------------------------------------------------------------------
local function rule(kind, size, held)
	local parts = {}
	for _, button in ipairs(grug_traders.quantities(kind, size, held)) do
		parts[#parts + 1] = button.key .. "=" .. button.count .. ":" .. button.label
	end
	return table.concat(parts, " ")
end
eq(rule("buy", 1), "1=1:1", "A gear: 1")
eq(rule("buy", 20), "1=1:1 5=5:5 20=20:20", "A a potion: 1 / 5 / 20")
eq(rule("buy", 100), "1=1:1 5=5:5 20=20:20 stack=100:Stack 100", "A arrows: 1 / 5 / 20 / Stack 100")
eq(rule("buy", 99), "1=1:1 5=5:5 20=20:20 stack=99:Stack 99", "A a 99-stack: 1 / 5 / 20 / Stack 99")
eq(rule("buy", 10), "1=1:1 5=5:5 stack=10:Stack 10", "A a 10-stack: 1 / 5 / Stack 10")
eq(rule("sell", 20, 13), "1=1:1 5=5:5 stack=13:Stack 13", "A 13 potions in a slot: 1 / 5 / Stack 13")
eq(rule("sell", 20, 20), "1=1:1 5=5:5 20=20:20", "A a full potion slot: 1 / 5 / 20")
eq(rule("sell", 100, 100), "1=1:1 5=5:5 20=20:20 stack=100:Stack 100", "A 100 arrows: Stack 100")
eq(rule("sell", 100, 3), "1=1:1 stack=3:Stack 3", "A 3 arrows: 1 / Stack 3")
eq(rule("sell", 99, 5), "1=1:1 5=5:5", "A 5 torches: 1 / 5 sells the slot")
eq(rule("sell", 1, 1), "1=1:1", "A one gear piece: 1")
eq(rule("sell", 99, 150), "1=1:1 5=5:5 20=20:20 stack=99:Stack 99", "A an oversized slot: at most one stack")
eq(rule("lot", 50, 0), "", "A a lot good below one lot: no button")
eq(rule("lot", 50, 1), "1=1:50", "A one lot: the lot's count, no All")
eq(rule("lot", 50, 3), "1=1:50 all=3:All", "A three lots: one lot and All")

local ARROW, POTION, TORCH, BAG_ITEM = "grug_gear:arrow", "grug_traders:potion_healing_weak",
	"default:torch", "grug_inventory:bag_small"
eq(ItemStack(ARROW):get_stack_max(), 100, "A an arrow stacks to 100")
eq(ItemStack(POTION):get_stack_max(), 20, "A a potion stacks to 20")
eq(ItemStack(TORCH):get_stack_max(), 99, "A a torch stacks to 99")
eq(ItemStack(BAG_ITEM):get_stack_max(), 1, "A a bag stacks to 1")

------------------------------------------------------------------------------
-- B. Buying.
------------------------------------------------------------------------------
local GENERAL, HUMAN_QM = "grug_traders:vendor_general_accord", "grug_traders:vendor_race_human"
local index_of, price_of = {}, {}
for i, entry in ipairs(grug_traders.stock) do index_of[entry.item], price_of[entry.item] = i, entry.price end
local A, P, T, B = index_of[ARROW], index_of[POTION], index_of[TORCH], index_of[BAG_ITEM]
check(A and P and T and B, "B the core shelf sells arrows, potions, torches and the bag")

local ann = W.player("ann", {faction = "accord", race = "dwarf", class = "warrior", copper = 1000})
W.open(ann, GENERAL, {mode_buy = "Buy"})
check(has("buy1_" .. B .. ";1]") and not has("buy5_" .. B .. ";") and not has("buystack_" .. B .. ";"),
	"B the bag (stack 1): one button")
check(has("buy1_" .. P .. ";1]") and has("buy5_" .. P .. ";5]") and has("buy20_" .. P .. ";20]") and
	not has("buystack_" .. P .. ";"), "B the potion: 1 / 5 / 20")
check(has("buy20_" .. A .. ";20]") and has("buystack_" .. A .. ";Stack 100]"), "B arrows: 1 / 5 / 20 / Stack 100")
check(has("buystack_" .. T .. ";Stack 99]"), "B torches: Stack 99")
check(has("tooltip[buy20_" .. A .. ";Buy 20 for " .. core.formspec_escape(grug_money.format(20 * price_of[ARROW])) .. "]"),
	"B a button's tooltip says its total")
check(not has("tooltip[buy1_"), "B the one-item button needs no tooltip (the row's price says it)")
check(has(core.formspec_escape(grug_money.format(price_of[ARROW]) .. " each")), "B the row's price each")

local before = grug_money.get(ann)
W.submit(ann, {["buy20_" .. A] = "20"})
eq(W.count_of(ann.inv, ARROW), 20, "B 20 arrows delivered")
eq(grug_money.get(ann), before - 20 * price_of[ARROW], "B ...and 20 prices paid")
check(has("Bought 20x"), "B the status line counts them")
W.submit(ann, {["buy20_" .. P] = "20"})
eq(W.count_of(ann.inv, POTION), 20, "B 20 potions delivered (the belt first)")
W.submit(ann, {["buy1_" .. B] = "1"})
eq(W.count_of(ann.inv, BAG_ITEM), 1, "B one bag")

-- Forged keys and amounts.
local frozen, purse = W.snapshot(ann.inv), grug_money.get(ann)
W.submit(ann, {["buystack_" .. B] = "x"})
W.submit(ann, {["buy5_" .. B] = "x"})
W.submit(ann, {["buystack_" .. P] = "x"})
W.submit(ann, {["buy37_" .. A] = "x"})
W.submit(ann, {["buy100_" .. A] = "x"})
W.submit(ann, {["buyall_" .. A] = "x"})
W.submit(ann, {["buy_" .. A] = "x"})
W.submit(ann, {["buy1_" .. (#grug_traders.stock + 1)] = "x"})
eq(W.snapshot(ann.inv), frozen, "B forged keys and amounts buy nothing")
eq(grug_money.get(ann), purse, "B ...and take nothing")

-- The kinship discount applies per item.
local hal = W.player("hal", {faction = "accord", race = "human", class = "warrior", copper = 1000})
W.open(hal, HUMAN_QM, {mode_buy = "Buy"})
local unit = grug_traders.discounted_price(price_of[ARROW])
check(unit < price_of[ARROW], "B the human pays less per arrow")
W.submit(hal, {["buy20_" .. A] = "20"})
eq(grug_money.get(hal), 1000 - 20 * unit, "B 20 arrows at the discounted price each")
eq(W.count_of(hal.inv, ARROW), 20, "B ...delivered")

-- An unaffordable amount: greyed, and a click refused whole.
local poor_money = 6 * price_of[ARROW]
local bea = W.player("bea", {faction = "accord", race = "dwarf", class = "warrior", copper = poor_money})
W.open(bea, GENERAL, {mode_buy = "Buy"})
check(has("buy5_" .. A .. ";5]") and not has("buy20_" .. A .. ";") and not has("buystack_" .. A .. ";"),
	"B six arrows' money: 1 and 5 buttons, 20 and Stack not")
check(greyed("20") and greyed("Stack 100"), "B ...20 and Stack 100 greyed")
W.submit(bea, {["buy20_" .. A] = "20"})
eq(W.count_of(bea.inv, ARROW), 0, "B a forged 20 delivers nothing")
eq(grug_money.get(bea), poor_money, "B ...and takes nothing")
check(has("Not enough money."), "B ...and says why")

-- A full inventory: every amount greyed, nothing paid.
local cy = W.player("cy", {faction = "accord", race = "dwarf", class = "warrior", copper = 1000})
for list, stacks in pairs(cy.inv.lists) do
	for i in ipairs(stacks) do cy.inv:set_stack(list, i, ItemStack("default:dirt 99")) end
end
W.open(cy, GENERAL, {mode_buy = "Buy"})
check(not has("buy1_" .. A .. ";") and not has("buy1_" .. B .. ";") and not has("buy1_" .. P .. ";"),
	"B a full inventory: no buy button")
frozen = W.snapshot(cy.inv)
W.submit(cy, {["buy1_" .. A] = "1"})
W.submit(cy, {["buy20_" .. P] = "20"})
eq(W.snapshot(cy.inv), frozen, "B a full inventory takes nothing in")
eq(grug_money.get(cy), 1000, "B ...and pays nothing")
check(has("You have no room for 20.") or has("Your inventory is full."), "B ...and says why")
-- Nearly full: room for four torches beside a partial stack.
cy.inv:set_stack("main", 9, ItemStack(TORCH .. " 95"))
W.open(cy, GENERAL, {mode_buy = "Buy"})
check(has("buy1_" .. T .. ";1]") and not has("buy5_" .. T .. ";"), "B room for four torches: 1, not 5")
W.submit(cy, {["buy5_" .. T] = "5"})
eq(W.count_of(cy.inv, TORCH), 95, "B five torches without room: none delivered")
eq(grug_money.get(cy), 1000, "B ...none paid")
W.submit(cy, {["buy1_" .. T] = "1"})
eq(W.count_of(cy.inv, TORCH), 96, "B one torch fits")
eq(grug_money.get(cy), 1000 - price_of[TORCH], "B ...for one price")

-- The shelf changed between the render and the click.
W.open(ann, GENERAL, {mode_buy = "Buy"})
local entry = grug_traders.stock[A]
local old_price = entry.price
entry.price = old_price + 1
frozen, purse = W.snapshot(ann.inv), grug_money.get(ann)
W.submit(ann, {["buy5_" .. A] = "5"})
eq(W.snapshot(ann.inv), frozen, "B a changed price: nothing delivered")
eq(grug_money.get(ann), purse, "B ...nothing paid")
check(has("The vendor's stock has changed."), "B ...the refusal re-renders")
entry.price = old_price

-- The gear tab: every row one button.
W.open(ann, GENERAL, {mode_buy = "Buy"}, {tab_1 = "T1"})
local gear = grug_traders.vendor_bracket_stock(grug_traders.get_vendor(GENERAL), 1)
check(#gear > 0, "B the gear tab has offers")
local stacked = false
for i, offer in ipairs(gear) do
	if ItemStack(offer.item):get_stack_max() == 1 then
		stacked = stacked or has("buy5_" .. i .. ";") or has("buystack_" .. i .. ";")
	end
end
check(has("buy1_1;1]") and not stacked, "B gear rows: 1 only")

------------------------------------------------------------------------------
-- C. Selling.
------------------------------------------------------------------------------
local dee = W.player("dee", {faction = "accord", race = "dwarf", class = "warrior"})
W.fill(dee, {{"main", 9, POTION .. " 13"}, {"main", 10, POTION .. " 20"},
	{"main", 11, "default:cobble 99"}, {"main", 12, "default:cobble 44"}, {"main", 13, "default:sand 49"}})
W.open(dee, GENERAL, {mode_sell = "Sell"})
local sell_unit = grug_traders.sell_price(POTION)
check(sell_unit > 0, "C the potion sells singly")
check(has("sell1_1;1]") and has("sell5_1;5]") and has("sellstack_1;Stack 13]") and not has("sell20_1;"),
	"C 13 potions: 1 / 5 / Stack 13")
check(has("sell20_2;20]") and not has("sellstack_2;"), "C 20 potions: 1 / 5 / 20, no Stack")
check(has("sell1_3;50]") and has("sellall_3;All (" .. core.formspec_escape(grug_money.format(
	2 * grug_traders.sell_offer(ItemStack("default:cobble")))) .. ")]"), "C 143 Cobblestone: one lot (50) and All")
check(has("Need 50 to sell") and not has("sell1_4;") and not has("sellall_4;"), "C 49 Sand: no button")
check(has("tooltip[sellstack_1;Sell 13 for " .. core.formspec_escape(grug_money.format(13 * sell_unit)) .. "]"),
	"C Stack's tooltip says its total")
-- A slot changed since the render: refused.
dee.inv:set_stack("main", 9, ItemStack(POTION .. " 10"))
W.submit(dee, {sellstack_1 = "x"})
eq(W.count_of(dee.inv, POTION), 30, "C a changed slot sells nothing")
eq(grug_money.get(dee), 0, "C ...pays nothing")
check(has("Your items have changed."), "C ...and says why")
check(has("sellstack_1;Stack 10]"), "C the fresh row shows Stack 10")
W.submit(dee, {sellstack_1 = "x"})
eq(W.count_of(dee.inv, POTION), 20, "C Stack sells the whole slot")
eq(grug_money.get(dee), 10 * sell_unit, "C ...for ten prices")
-- The lot row: one lot, then All gone at one lot.
local cobble_copper = grug_traders.sell_offer(ItemStack("default:cobble"))
local money = grug_money.get(dee)
local lot_row
for i = 1, 3 do if has("sell1_" .. i .. ";50]") then lot_row = i end end
W.submit(dee, {["sell1_" .. lot_row] = "x"})
eq(W.count_of(dee.inv, "default:cobble"), 93, "C one lot sells 50")
eq(grug_money.get(dee), money + cobble_copper, "C ...for one lot's copper")
for i = 1, 3 do if has("sell1_" .. i .. ";50]") then lot_row = i end end
check(not has("sellall_" .. lot_row .. ";"), "C one lot left: no All")
W.submit(dee, {["sellall_" .. lot_row] = "x"})
eq(W.count_of(dee.inv, "default:cobble"), 93, "C a forged All at one lot sells nothing")
W.submit(dee, {["sell5_" .. lot_row] = "x"})
eq(W.count_of(dee.inv, "default:cobble"), 93, "C a forged 5 on a lot row sells nothing")

------------------------------------------------------------------------------
-- D. The Trade-in.
------------------------------------------------------------------------------
local key_of = {}
for index, rate in ipairs(C.EXCHANGE) do key_of[rate.item] = index end
local COBBLE, SILVER = key_of["default:cobble"], key_of["grug_materials:silver_lump"]
local eve = W.player("eve", {faction = "accord", race = "dwarf", class = "warrior"})
W.fill(eve, {{"main", 9, "default:cobble 103"}, {"main", 10, "grug_materials:silver_lump 3"}})
W.open(eve, "grug_traders:guild_exchange")
check(has("tradein1_" .. COBBLE .. ";50]") and has("tradeinall_" .. COBBLE .. ";All (2)]"),
	"D Cobblestone x103: one lot (50) and All (2)")
check(has("tradein1_" .. SILVER .. ";1]") and has("tradeinall_" .. SILVER .. ";All (24)]"),
	"D Silver x3: one lot (1) and All (24)")
check(not has("tradein5_") and not has("tradein10_"), "D no 5 or 10 lots")
local life = grug_guild.lifetime(eve)
W.submit(eve, {["tradein1_" .. COBBLE] = "x"})
eq(W.count_of(eve.inv, "default:cobble"), 53, "D one lot traded")
eq(grug_guild.lifetime(eve), life + 1, "D ...for one point")
check(not has("tradeinall_" .. COBBLE .. ";"), "D one lot left: no All")
W.submit(eve, {["tradeinall_" .. SILVER] = "x"})
eq(W.count_of(eve.inv, "grug_materials:silver_lump"), 0, "D All trades every lot")

------------------------------------------------------------------------------
-- E. The Stonewright.
------------------------------------------------------------------------------
local fay = W.player("fay", {faction = "accord", race = "dwarf", class = "warrior", copper = 50})
grug_guild.add(fay, C.RANKS[2], "test")
W.fill(fay, {{"main", 9, "default:cobble 57"}})
W.open(fay, "grug_traders:stonewright")
local first = C.STONEWRIGHT[1]
check(has("stone1_1;" .. first.output_count .. "]") and
	has("stoneall_1;All (" .. 5 * first.output_count .. ")]"), "E one conversion and All, by what they make")
check(not has("stone5_1;") and not has("stone10_1;"), "E no 5 or 10 lots")
W.submit(fay, {stone1_1 = "x"})
eq(W.count_of(fay.inv, first.output), first.output_count, "E one conversion made")
W.submit(fay, {stone5_1 = "x"})
eq(W.count_of(fay.inv, first.output), first.output_count, "E a forged 5 makes nothing")

------------------------------------------------------------------------------
-- F. The reputation page.
------------------------------------------------------------------------------
local KEY = {}
for index, row in ipairs(C.CONSUMABLES) do KEY[row.item] = index end
local T1 = C.consumable(C.KINDS[1], 1)
local gus = W.player("gus", {faction = "accord", race = "dwarf", class = "warrior"})
grug_guild.add(gus, C.RANKS[3], "test")
local balance = grug_guild.balance(gus)
local size = ItemStack(T1.item):get_stack_max()
eq(size, 20, "F a consumable stacks to 20")
W.open(gus, "grug_traders:vendor_camp", {mode_buy = "Buy"})
local k = KEY[T1.item]
local affordable = math.floor(balance / T1.price)
check(affordable >= 5 and affordable < 20, "F rank 3's balance pays for 5, not 20 (" .. affordable .. ")")
check(has("repbuy1_" .. k .. ";1]") and has("repbuy5_" .. k .. ";5]"), "F the page's 1 and 5 buttons")
check(not has("repbuy20_" .. k .. ";") and greyed("20"), "F an unaffordable 20 is greyed")
check(not has("repbuystack_" .. k .. ";"), "F no Stack beside 20 for a 20-stack")
check(has("tooltip[repbuy5_" .. k .. ";Buy 5 for " .. core.formspec_escape(grug_guild.format_points(5 * T1.price)) ..
	" reputation]"), "F the tooltip says the total")
W.submit(gus, {["repbuy5_" .. k] = "x"})
eq(W.count_of(gus.inv, T1.item), 5, "F five bought")
eq(grug_guild.balance(gus), balance - 5 * T1.price, "F ...for five prices")
check(has("Bought 5x"), "F the status line counts them")
-- An amount the balance cannot pay is refused whole.
local left = grug_guild.balance(gus)
W.submit(gus, {["repbuy20_" .. k] = "x"})
eq(W.count_of(gus.inv, T1.item), 5, "F a forged 20 delivers nothing")
eq(grug_guild.balance(gus), left, "F ...and spends nothing")
check(has("Not enough reputation."), "F ...and says why")
-- grug_guild.buy's count.
for _, bad in ipairs({0, -1, 1.5, 21, "5", false, 0 / 0, math.huge}) do
	local ok, err = grug_guild.buy(gus, T1.item, bad)
	check(not ok and err == "count", "F a bad count is refused: " .. tostring(bad))
end
eq(grug_guild.balance(gus), left, "F bad counts spend nothing")
local ok = grug_guild.buy(gus, T1.item)
check(ok, "F no count buys one")

------------------------------------------------------------------------------
-- G. A click from a form drawn before the last render acts on nothing (fix
--    round 1: a double click on Stack, the next item moved into the row).
------------------------------------------------------------------------------
local IRON = "grug_materials:iron_bar"
check(grug_traders.sell_price(IRON) > 0 and grug_traders.sell_price(POTION) > 0, "G both sell singly")
local ida = W.player("ida", {faction = "accord", race = "dwarf", class = "warrior", copper = 1000})
W.fill(ida, {{"main", 9, POTION .. " 13"}, {"main", 10, IRON .. " 13"}})
W.open(ida, GENERAL, {mode_sell = "Sell"})
local old_name = W.formname(ida)
check(has("sellstack_1;Stack 13]") and has("sellstack_2;Stack 13]"), "G two rows of 13")
W.submit_as(ida, old_name, {sellstack_1 = "x"})
eq(W.count_of(ida.inv, POTION), 0, "G the first click sells the potions")
check(W.formname(ida) ~= old_name and has("sellstack_1;Stack 13]"), "G a new form: the bars moved into row 1")
local money_now = grug_money.get(ida)
local drawn = W.shown()
W.submit_as(ida, old_name, {sellstack_1 = "x"})
eq(W.count_of(ida.inv, IRON), 13, "G the second click from the old form sells nothing")
eq(grug_money.get(ida), money_now, "G ...pays nothing")
eq(W.shown(), drawn, "G ...and draws nothing")
W.submit_as(ida, old_name, {quit = "true"})
W.submit(ida, {sell5_1 = "x"})
eq(W.count_of(ida.inv, IRON), 8, "G the old form's quit is dropped; a fresh click sells")
-- Buying: a double click buys once.
W.open(ida, GENERAL, {mode_buy = "Buy"})
old_name = W.formname(ida)
W.submit_as(ida, old_name, {["buy5_" .. A] = "5"})
money_now = grug_money.get(ida)
W.submit_as(ida, old_name, {["buy5_" .. A] = "5"})
eq(W.count_of(ida.inv, ARROW), 5, "G a double click buys once")
eq(grug_money.get(ida), money_now, "G ...and pays once")
W.submit(ida, {["buy5_" .. A] = "5"})
eq(W.count_of(ida.inv, ARROW), 10, "G a fresh click buys")
-- Page turns and tabs from the current form still work.
W.submit(ida, {tab_1 = "T1"})
check(has("buy1_1;1]") and W.formname(ida) ~= old_name, "G a tab switch from the current form")
-- The Trade-in, the Stonewright and the reputation page.
W.fill(ida, {{"main", 11, "default:cobble 150"}})
grug_guild.add(ida, C.RANKS[3], "test")
W.open(ida, "grug_traders:guild_exchange")
old_name = W.formname(ida)
W.submit_as(ida, old_name, {["tradein1_" .. COBBLE] = "x"})
W.submit_as(ida, old_name, {["tradein1_" .. COBBLE] = "x"})
eq(W.count_of(ida.inv, "default:cobble"), 100, "G Trade-in: a double click trades one lot")
W.open(ida, "grug_traders:stonewright")
old_name = W.formname(ida)
W.submit_as(ida, old_name, {stone1_1 = "x"})
W.submit_as(ida, old_name, {stone1_1 = "x"})
eq(W.count_of(ida.inv, first.output), first.output_count, "G Stonewright: a double click makes one lot")
W.open(ida, "grug_traders:vendor_camp", {mode_buy = "Buy"})
old_name = W.formname(ida)
W.submit_as(ida, old_name, {["repbuy1_" .. k] = "x"})
W.submit_as(ida, old_name, {["repbuy1_" .. k] = "x"})
eq(W.count_of(ida.inv, T1.item), 1, "G the reputation page: a double click buys once")
W.submit_as(ida, "grug_traders:trade", {["repbuy1_" .. k] = "x"})
eq(W.count_of(ida.inv, T1.item), 1, "G the bare name acts on nothing")

if failures > 0 then
	error("R84 TRADE PORTABLE FAIL " .. failures .. " of " .. checks)
end
print("R84 TRADE PORTABLE PASS checks=" .. checks)
