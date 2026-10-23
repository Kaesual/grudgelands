-- Round 58 lane REP portable fixture (LuaJIT): reputation, the trade-in, the
-- vendor's Trade-in mode, the Miner's Guild achievement series and the
-- mason's shelf, on the whole game's registrations (the Round 57 game
-- harness, tools/r57_details/game_harness.lua) with fake players.
--
--   luajit tools/r58_rep/portable_test.lua REPO
--
-- A. The store (grug_guild/store.lua): add, spend and rank across the
--    thresholds; spend refusing and never touching the lifetime; bad
--    amounts; no faction; clamping at 2147483647; the per-faction keys and
--    an admin faction switch (the other guild at its own values, the old
--    ones kept); the change callbacks once per change, the rank callbacks
--    only when the rank rose; the number format and the display helpers.
-- B. The trade-in (grug_guild/exchange.lua): rows in catalogue order over
--    main, a bag and the inactive hotbar, stacks with meta counted; whole
--    lots taken over several lists and the rest kept; too few, a
--    non-exchanged item and no faction refused with nothing taken.
-- C. The vendor window (grug_traders/trade.lua) at a test vendor with
--    `guild = true`: opens on Trade-in with the guild, rank and balance, a
--    row per item; All trades and re-renders; a stale row and a forged click
--    take nothing; a vendor without the field has no Trade-in mode.
-- D. The achievement series (grug_achievements): the cloaks unlock at rank
--    3, 6 and 10 through the rank hook; a faction switch keeps them.
-- E. Round 58 §2a: the mason sells no Cobblestone or Gravel, no shelf sells
--    an exchanged item, both are exchanged; the consumables' vendor payout
--    is the catalogue's sell_copper.
-- Prints "R58 REP PORTABLE PASS checks=<n>" or raises.

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

local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
for _, line in ipairs(game.failures) do
	check(not (line:find("grug_guild", 1, true) or line:find("grug_traders", 1, true) or
		line:find("grug_achievements", 1, true)), "the mods load in the harness: " .. line)
end
local C = grug_guild.catalog

------------------------------------------------------------------------------
-- Fake players: meta, an inventory with the engine's remove_item (from the
-- end of a list, by name, meta ignored), online through get_player_by_name.
------------------------------------------------------------------------------
local function new_meta()
	local data = {}
	return {
		get_int = function(_, key) return math.floor(tonumber(data[key]) or 0) end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value end,
		contains = function(_, key) return data[key] ~= nil end,
		data = data,
	}
end

local BAG = grug_inventory.content_list(1)
local STORE = grug_inventory.HOTBAR_STORE
local function new_inv()
	local lists = {}
	local sizes = {main = 32, [BAG] = 8, [STORE] = 8}
	for list, size in pairs(sizes) do
		lists[list] = {}
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {lists = lists, removes = 0}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
	function inv:remove_item(list, stack)
		self.removes = self.removes + 1
		local want, got = stack:get_count(), 0
		for i = #lists[list], 1, -1 do
			if got >= want then break end
			local slot = lists[list][i]
			if slot:get_name() == stack:get_name() and slot:get_count() > 0 then
				got = got + slot:take_item(want - got):get_count()
			end
		end
		return ItemStack(stack:get_name() .. " " .. got)
	end
	return inv
end
local function count_of(inv, name, only)
	local n = 0
	for list, stacks in pairs(inv.lists) do
		if not only or only == list then
			for _, stack in ipairs(stacks) do
				if stack:get_name() == name then n = n + stack:get_count() end
			end
		end
	end
	return n
end
local function snapshot(inv)
	local parts = {}
	for _, list in ipairs({"main", BAG, STORE}) do
		for i, stack in ipairs(inv.lists[list]) do
			parts[#parts + 1] = list .. i .. "=" .. stack:get_name() .. " " .. stack:get_count()
		end
	end
	return table.concat(parts, ";")
end

local online = {}
local function new_player(name, faction)
	local meta, inv = new_meta(), new_inv()
	if faction then meta:set_string("grug_factions:faction", faction) end
	local player = {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_meta = function() return meta end,
		get_inventory = function() return inv end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		meta = meta, inv = inv,
	}
	online[name] = player
	return player
end
core.get_player_by_name = function(name) return online[name] end
-- As /faction (grug_factions.set_faction) writes it: the faction id in meta.
local function switch_faction(player, faction)
	player.meta:set_string("grug_factions:faction", faction)
end

-- Count the callbacks (registered after the game's own).
local changes, ranks = {}, {}
grug_guild.register_on_change(function(player, faction, lifetime, balance)
	changes[#changes + 1] = {name = player:get_player_name(), faction = faction,
		lifetime = lifetime, balance = balance}
end)
grug_guild.register_on_rank_change(function(player, faction, new_rank, old_rank)
	ranks[#ranks + 1] = {name = player:get_player_name(), faction = faction,
		new = new_rank, old = old_rank}
end)
local function reset_calls() changes, ranks = {}, {} end

------------------------------------------------------------------------------
-- A. The store.
------------------------------------------------------------------------------
local ann = new_player("ann", "accord")
eq(grug_guild.lifetime(ann), 0, "A a new character's lifetime")
eq(grug_guild.balance(ann), 0, "A a new character's balance")
eq(grug_guild.rank(ann), 0, "A a new character is rank 0")
check(next(ann.meta.data) == "grug_factions:faction" and next(ann.meta.data, "grug_factions:faction") == nil,
	"A reading creates no key (created on first use)")

reset_calls()
local lifetime, balance = grug_guild.add(ann, C.RANKS[1] - 1, "test")
eq(lifetime, C.RANKS[1] - 1, "A add returns the lifetime")
eq(balance, C.RANKS[1] - 1, "A add returns the balance")
eq(grug_guild.rank(ann), 0, "A one point below rank 1")
eq(#changes, 1, "A one change callback for one add")
eq(#ranks, 0, "A no rank callback below the threshold")
eq(ann.meta:get_int("grug_guild:lifetime_accord"), C.RANKS[1] - 1, "A the lifetime key per faction")
eq(ann.meta:get_int("grug_guild:balance_accord"), C.RANKS[1] - 1, "A the balance key per faction")
check(changes[1] and changes[1].faction == "accord" and changes[1].lifetime == C.RANKS[1] - 1 and
	changes[1].balance == C.RANKS[1] - 1, "A the change callback's arguments")

reset_calls()
grug_guild.add(ann, 1, "test")
eq(grug_guild.rank(ann), 1, "A exactly at rank 1")
eq(#ranks, 1, "A one rank callback at the threshold")
check(ranks[1] and ranks[1].new == 1 and ranks[1].old == 0 and ranks[1].faction == "accord",
	"A the rank callback's arguments (1, 0)")

reset_calls()
grug_guild.add(ann, C.RANKS[4] - C.RANKS[1], "test") -- 200 -> 9,000: three ranks at once
eq(grug_guild.rank(ann), 4, "A three ranks in one add")
eq(#ranks, 1, "A one rank callback for a jump over several ranks")
check(ranks[1] and ranks[1].new == 4 and ranks[1].old == 1, "A the jump's callback (4, 1)")
eq(#changes, 1, "A one change callback for the jump")

reset_calls()
local after = grug_guild.spend(ann, C.RANKS[4])
eq(after, 0, "A spend returns the balance")
eq(grug_guild.balance(ann), 0, "A the balance is spent")
eq(grug_guild.lifetime(ann), C.RANKS[4], "A spending never touches the lifetime")
eq(grug_guild.rank(ann), 4, "A spending keeps the rank")
eq(#changes, 1, "A one change callback for a spend")
eq(#ranks, 0, "A a spend fires no rank callback")

reset_calls()
local none, err = grug_guild.spend(ann, 1)
check(none == nil and err == "insufficient", "A spend refuses a short balance (insufficient)")
eq(grug_guild.lifetime(ann), C.RANKS[4], "A a refused spend keeps the lifetime")
eq(#changes, 0, "A a refused spend fires nothing")
for _, bad in ipairs({0, -5, 1.5, "10", math.huge * 0, math.huge, 1e999}) do
	local a, a_err = grug_guild.add(ann, bad, "test")
	local s, s_err = grug_guild.spend(ann, bad)
	check(a == nil and a_err == "bad_amount", "A add refuses " .. tostring(bad))
	check(s == nil and s_err == "bad_amount", "A spend refuses " .. tostring(bad))
end
eq(#changes, 0, "A refused amounts fire nothing")
eq(grug_guild.lifetime(ann), C.RANKS[4], "A refused amounts change nothing")

-- No faction: no guild.
local nob = new_player("nob", nil)
local n_add, n_err = grug_guild.add(nob, 10, "test")
check(n_add == nil and n_err == "no_faction", "A add without a faction (no_faction)")
local s_add, s_err = grug_guild.spend(nob, 10)
check(s_add == nil and s_err == "no_faction", "A spend without a faction (no_faction)")
eq(grug_guild.rank(nob), 0, "A no faction reads rank 0")
eq(grug_guild.summary(nob), nil, "A no faction has no summary")
eq(next(nob.meta.data), nil, "A no faction writes nothing")

-- Clamping.
local max = new_player("max", "throng")
reset_calls()
grug_guild.add(max, grug_guild.MAX_POINTS - 5, "test")
grug_guild.add(max, 100, "test")
eq(grug_guild.lifetime(max), 2147483647, "A the lifetime clamps at 2147483647")
eq(grug_guild.balance(max), 2147483647, "A the balance clamps at 2147483647")
eq(grug_guild.rank(max), 10, "A the clamp is rank 10")
eq(#ranks, 1, "A rank 10 fires once")
eq(#changes, 2, "A two adds, two change callbacks")
max.meta:set_int("grug_guild:balance_throng", -40)
eq(grug_guild.balance(max), 0, "A a negative stored balance reads 0")

-- The admin faction switch: the other guild at its own values, the old kept.
local cy = new_player("cy", "accord")
grug_guild.add(cy, C.RANKS[3], "test")
grug_guild.spend(cy, 100)
switch_faction(cy, "throng")
eq(grug_guild.lifetime(cy), 0, "A after the switch: the other guild's lifetime (0)")
eq(grug_guild.balance(cy), 0, "A after the switch: the other guild's balance (0)")
eq(grug_guild.summary(cy).guild, "The Oathdelvers", "A after the switch: The Oathdelvers")
reset_calls()
grug_guild.add(cy, 50, "test")
check(ranks[1] == nil and changes[1].faction == "throng", "A the switched guild's change callback")
eq(cy.meta:get_int("grug_guild:lifetime_throng"), 50, "A the switched guild's own key")
eq(cy.meta:get_int("grug_guild:lifetime_accord"), C.RANKS[3], "A the old guild's lifetime kept")
eq(cy.meta:get_int("grug_guild:balance_accord"), C.RANKS[3] - 100, "A the old guild's balance kept")
eq(grug_guild.highest_rank(cy), 3, "A the highest rank with either guild")
switch_faction(cy, "accord")
eq(grug_guild.rank(cy), 3, "A back: the old rank")
eq(grug_guild.balance(cy), C.RANKS[3] - 100, "A back: the old balance")
eq(grug_guild.summary(cy).guild, "The Charter of Stone", "A back: The Charter of Stone")

-- Display.
eq(grug_guild.format_points(0), "0", "A format 0")
eq(grug_guild.format_points(999), "999", "A format 999")
eq(grug_guild.format_points(1234), "1,234", "A format 1,234")
eq(grug_guild.format_points(350000), "350,000", "A format 350,000")
eq(grug_guild.format_points(2147483647), "2,147,483,647", "A format the clamp")
eq(grug_guild.reputation_formspec(1, 2, 1234), "label[1.00,2.00;Reputation 1,234]",
	"A reputation drawn as text until the icon is picked")
local view = grug_guild.summary(ann)
check(view.rank == 4 and view.lifetime == C.RANKS[4] and view.balance == 0 and
	view.next == C.RANKS[5] and view.guild == "The Charter of Stone", "A the summary")
eq(grug_guild.summary(max).next, nil, "A no next rank at rank 10")

------------------------------------------------------------------------------
-- B. The trade-in.
------------------------------------------------------------------------------
local function fill(player, slots)
	for _, slot in ipairs(slots) do
		local stack = ItemStack(slot[3])
		if slot[4] then stack:get_meta():set_int("grug_quality", slot[4]) end
		player.inv:set_stack(slot[1], slot[2], stack)
	end
end
local dee = new_player("dee", "accord")
fill(dee, {
	{"main", 9, "default:cobble 30"}, {"main", 12, "default:cobble 30"}, {BAG, 2, "default:cobble 43"},
	{"main", 10, "default:iron_lump 4"}, {STORE, 3, "default:iron_lump 2", 3},
	{"main", 11, "grug_materials:rough_diamond 1"},
	{"main", 13, "default:sand 49"},
	{"main", 14, "default:stonebrick 99"},
	{"main", 15, "default:gravel 60"},
})
local rows = grug_guild.trade_in_rows(dee)
local by = {}
for index, row in ipairs(rows) do
	row.index = index
	by[row.item] = row
end
check(by["default:cobble"] and by["default:cobble"].count == 103 and by["default:cobble"].lot == 50 and
	by["default:cobble"].lots == 2 and by["default:cobble"].total == 2 and by["default:cobble"].rest == 3,
	"B Cobblestone over two main slots and a bag: 103, two lots, 3 rest")
check(by["default:iron_lump"] and by["default:iron_lump"].count == 6 and by["default:iron_lump"].total == 6,
	"B Iron Lump over main and the inactive hotbar, a quality stack counted")
check(by["grug_materials:rough_diamond"] and by["grug_materials:rough_diamond"].total == 128,
	"B a Rough Diamond is worth 128")
check(by["default:sand"] and by["default:sand"].lots == 0 and by["default:sand"].total == 0,
	"B 49 Sand: a row below one lot")
check(by["default:gravel"] and by["default:gravel"].lots == 1, "B Gravel is exchanged (pending gone)")
eq(by["default:stonebrick"], nil, "B a made good has no row")
local order_ok = true
for i = 2, #rows do
	local a, b
	for index, rate in ipairs(C.EXCHANGE) do
		if rate.item == rows[i - 1].item then a = index end
		if rate.item == rows[i].item then b = index end
	end
	order_ok = order_ok and a < b
end
check(order_ok, "B rows in catalogue order")
eq(#rows, 5, "B one row per exchanged item carried")

local before = snapshot(dee.inv)
local life0 = grug_guild.lifetime(dee)
local p, perr = grug_guild.trade_in(dee, "default:stonebrick")
check(p == nil and perr == "not_exchanged", "B a made good is refused (not_exchanged)")
p, perr = grug_guild.trade_in(dee, "default:dirt")
check(p == nil and perr == "not_exchanged", "B an item the guild never takes (not_exchanged)")
p, perr = grug_guild.trade_in(dee, "default:sand")
check(p == nil and perr == "too_few", "B 49 Sand refused (too_few)")
p, perr = grug_guild.trade_in(dee, "default:clay_lump")
check(p == nil and perr == "not_exchanged", "B a non-exchanged item not carried")
p, perr = grug_guild.trade_in(dee, "default:mossycobble")
check(p == nil and perr == "too_few", "B an exchanged item not carried (too_few)")
eq(snapshot(dee.inv), before, "B nothing taken on a refusal")
eq(grug_guild.lifetime(dee), life0, "B no reputation on a refusal")
eq(dee.inv.removes, 0, "B remove_item never called on a refusal")

reset_calls()
local points, l2, b2 = grug_guild.trade_in(dee, "default:cobble")
eq(points, 2, "B 103 Cobblestone: 2 points")
eq(l2, life0 + 2, "B the lifetime after the trade")
eq(b2, life0 + 2, "B the balance after the trade")
eq(count_of(dee.inv, "default:cobble"), 3, "B 3 Cobblestone stay")
eq(#changes, 1, "B one change callback per trade")
points = grug_guild.trade_in(dee, "default:iron_lump")
eq(points, 6, "B 6 Iron Lump: 6 points")
eq(count_of(dee.inv, "default:iron_lump"), 0, "B every Iron Lump taken, the inactive hotbar's too")
eq(count_of(dee.inv, "default:sand"), 49, "B the other items stay")
eq(count_of(dee.inv, "default:stonebrick"), 99, "B the made good stays")
p, perr = grug_guild.trade_in(dee, "default:cobble")
check(p == nil and perr == "too_few", "B the 3 left are too few")
local stranger = new_player("stranger", nil)
fill(stranger, {{"main", 9, "default:iron_lump 5"}})
p, perr = grug_guild.trade_in(stranger, "default:iron_lump")
check(p == nil and perr == "no_faction", "B no faction refused")
eq(count_of(stranger.inv, "default:iron_lump"), 5, "B nothing taken without a faction")

------------------------------------------------------------------------------
-- C. The vendor window.
------------------------------------------------------------------------------
local shown, shown_name
core.show_formspec = function(name, formname, formspec)
	if formname == "grug_traders:trade" then shown, shown_name = formspec, name end
end
core.close_formspec = function() end
core.chat_send_player = function() end
vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end}
local handlers = rawget(core, "registered_on_player_receive_fieldss") or {}
local function submit(player, fields)
	for _, fn in ipairs(handlers) do
		if fn(player, "grug_traders:trade", fields) then return end
	end
end
local function has(text) return shown ~= nil and shown:find(text, 1, true) ~= nil end
check(#handlers > 0, "C the trade window's field handler is registered")

local TEST = "grug_traders:r58_test_guild_vendor"
grug_traders.vendors[TEST] = {name = TEST, kind = "r58_test", faction = "accord",
	nametag = "Test Guild Vendor", stock = "r58_test", guild = true}
grug_traders.profession_stock.r58_test = {}
local ORIGIN = {x = 0, y = 0, z = 0}
-- A Trade-in button carries its item's catalogue index.
local KEY = {}
for index, rate in ipairs(C.EXCHANGE) do KEY[rate.item] = index end
local COBBLE, SAND, SILVER = KEY["default:cobble"], KEY["default:sand"], KEY["grug_materials:silver_lump"]

local eve = new_player("eve", "accord")
grug_guild.add(eve, C.RANKS[3] + 34, "test")
grug_guild.spend(eve, 1500)
fill(eve, {{"main", 9, "default:cobble 60"}, {BAG, 1, "default:cobble 43"},
	{"main", 10, "default:sand 49"}, {"main", 11, "grug_materials:silver_lump 3"}})
shown = nil
grug_traders.open(eve, TEST, ORIGIN, "accord")
check(has("mode_tradein;Trade-in]"), "C a guild vendor shows the Trade-in mode")
check(has("button[8.2,0.3;1.6,0.8;mode_buy;Buy]") and has("button[9.9,0.3;1.5,0.8;mode_sell;Sell]"),
	"C Buy and Sell move left")
check(has("label[0.6,1.75;Miner's Guild]"), "C opens on Trade-in: Miner's Guild")
check(not has("Charter of Stone") and not has("Oathdelvers"),
	"C no proper name in the interface (the user's ruling)")
check(has("Rank 3 of 10"), "C the rank")
check(has("Reputation " .. grug_guild.format_points(C.RANKS[3] + 34 - 1500)), "C the balance")
check(has("Lifetime " .. grug_guild.format_points(C.RANKS[3] + 34) .. " of " ..
	grug_guild.format_points(C.RANKS[4]) .. " for Rank 4"), "C the lifetime and the next rank")
check(has("Cobblestone x103") and has("1 point per 50") and has("tradein_" .. COBBLE .. ";All (2)]"),
	"C the Cobblestone row: 103, 1 point per 50, All (2)")
check(has("Sand x49") and has("Need 50 to trade") and not has("tradein_" .. SAND .. ";"),
	"C 49 Sand: greyed, Need 50 to trade, no button")
check(has("Silver x3") and has("8 points each") and has("tradein_" .. SILVER .. ";All (24)]"),
	"C the Silver row: 8 points each, All (24)")

-- All on the first row.
local life_before = grug_guild.lifetime(eve)
local old_form = shown
submit(eve, {["tradein_" .. COBBLE] = "x"})
eq(grug_guild.lifetime(eve), life_before + 2, "C All traded 2 points")
eq(count_of(eve.inv, "default:cobble"), 3, "C 3 Cobblestone stay")
check(has("Traded 100 Cobblestone for 2 reputation. 3 left."), "C the status line")
check(has("Cobblestone x3") and has("Need 50 to trade"), "C the rest shows greyed")
-- A second click on the same button of the old form: the row is greyed now,
-- and the click never reaches the next row's item.
check(old_form:find("tradein_" .. COBBLE .. ";", 1, true) ~= nil, "C the old form had the button")
local twice_life = grug_guild.lifetime(eve)
submit(eve, {["tradein_" .. COBBLE] = "x"})
eq(grug_guild.lifetime(eve), twice_life, "C a second click from the old form trades nothing")
eq(count_of(eve.inv, "grug_materials:silver_lump"), 3, "C ...and never the next row's item")
-- A forged click on the greyed row trades nothing.
submit(eve, {["tradein_" .. SAND] = "x"})
eq(count_of(eve.inv, "default:sand"), 49, "C a forged All on a greyed row takes nothing")
-- A stale row: the stack moved between render and click.
eve.inv:set_stack("main", 11, ItemStack("grug_materials:silver_lump 2"))
local stale_life = grug_guild.lifetime(eve)
submit(eve, {["tradein_" .. SILVER] = "x"})
check(has("Your items have changed."), "C a stale row re-renders with the refusal")
eq(count_of(eve.inv, "grug_materials:silver_lump"), 2, "C a stale row takes nothing")
eq(grug_guild.lifetime(eve), stale_life, "C a stale row credits nothing")
submit(eve, {["tradein_" .. SILVER] = "x"})
eq(grug_guild.lifetime(eve), stale_life + 16, "C the fresh row trades")
-- A row that the first click empties: the second click from the same old
-- form trades nothing, never the item that moved up into its place.
local hal = new_player("hal", "accord")
fill(hal, {{"main", 9, "grug_materials:silver_lump 2"}, {"main", 10, "grug_materials:rough_jade 1"}})
grug_traders.open(hal, TEST, ORIGIN, "accord")
submit(hal, {["tradein_" .. SILVER] = "x"})
eq(count_of(hal.inv, "grug_materials:silver_lump"), 0, "C the Silver row traded and gone")
local hal_life = grug_guild.lifetime(hal)
submit(hal, {["tradein_" .. SILVER] = "x"})
eq(count_of(hal.inv, "grug_materials:rough_jade"), 1, "C a second click never trades the next item")
eq(grug_guild.lifetime(hal), hal_life, "C ...and credits nothing")

-- Switching modes.
submit(eve, {mode_sell = "Sell"})
check(has("The vendor buys most things") and not has("label[0.6,1.75;Miner's Guild]"), "C Sell from the guild vendor")
submit(eve, {mode_tradein = "Trade-in"})
check(has("label[0.6,1.75;Miner's Guild]"), "C back to Trade-in")
submit(eve, {mode_buy = "Buy"})
-- Round 58 CAMPNPC: an empty guild vendor's shelf says where the guild sells.
check(has("The Miner's Guild sells its goods at the mining camps."), "C Buy at the test vendor")

-- A vendor without the field has no Trade-in mode, and forged fields do nothing.
fill(eve, {{"main", 12, "default:iron_lump 4"}})
shown = nil
grug_traders.open(eve, "grug_traders:vendor_general_accord", ORIGIN, "accord")
check(shown ~= nil and not has("mode_tradein"), "C a vendor without `guild` has no Trade-in")
check(has("button[10.3,0.3;1.6,0.8;mode_buy;Buy]"), "C its Buy button stays where it was")
submit(eve, {mode_tradein = "Trade-in"})
check(not has("label[0.6,1.75;Miner's Guild]"), "C a forged Trade-in field is ignored")
local life_plain = grug_guild.lifetime(eve)
for i = 1, #C.EXCHANGE do submit(eve, {["tradein_" .. i] = "x"}) end
eq(grug_guild.lifetime(eve), life_plain, "C a forged trade at a plain vendor credits nothing")
eq(count_of(eve.inv, "default:iron_lump"), 4, "C ...and takes nothing")

-- The other faction is refused at the door.
local fay = new_player("fay", "throng")
shown = nil
grug_traders.open(fay, TEST, ORIGIN, "accord")
eq(shown, nil, "C the other faction gets no window")
-- Walking away closes it.
grug_traders.open(eve, TEST, ORIGIN, "accord")
eve.get_pos = function() return {x = 20, y = 0, z = 0} end
local far_life = grug_guild.lifetime(eve)
submit(eve, {["tradein_" .. KEY["default:iron_lump"]] = "x"})
eq(grug_guild.lifetime(eve), far_life, "C out of range nothing trades")
eq(count_of(eve.inv, "default:iron_lump"), 4, "C ...and takes nothing")
eve.get_pos = function() return {x = 0, y = 0, z = 0} end

------------------------------------------------------------------------------
-- D. The achievement series.
------------------------------------------------------------------------------
local book = grug_achievements.book
local ach = book.achievement.miners_guild
check(ach ~= nil and ach.counter == "guild:rank" and ach.faction == nil, "D the row miners_guild on guild:rank, both factions")
check(ach and #ach.tiers == 3 and ach.tiers[1].at == 3 and ach.tiers[2].at == 6 and ach.tiers[3].at == 10,
	"D tiers at 3, 6 and 10")
check(book.cloak.miners_guild_3 and book.cloak.miners_guild_3.wings ~= nil, "D rank 10's cloak has wings")
local function owns(player, id)
	for _, cloak in ipairs(grug_achievements.unlocked_cloaks(player)) do
		if cloak == id then return true end
	end
	return false
end
local gus = new_player("gus", "throng")
grug_guild.add(gus, C.RANKS[3] - 1, "test")
check(not owns(gus, "miners_guild_1"), "D below rank 3: no cloak")
grug_guild.add(gus, 1, "test")
check(owns(gus, "miners_guild_1"), "D rank 3 unlocks the first cloak")
check(not owns(gus, "miners_guild_2"), "D ...and not the second")
grug_guild.add(gus, C.RANKS[6] - C.RANKS[3], "test")
check(owns(gus, "miners_guild_2"), "D rank 6 unlocks the second cloak")
grug_guild.spend(gus, C.RANKS[6])
check(not owns(gus, "miners_guild_3"), "D spending earns nothing")
switch_faction(gus, "accord")
check(owns(gus, "miners_guild_2"), "D a faction switch keeps the cloaks")
grug_guild.add(gus, C.RANKS[9], "test") -- rank 9 with the other guild: the highest stays 9
check(not owns(gus, "miners_guild_3"), "D rank 9 with the second guild: no winged cloak")
grug_guild.add(gus, C.RANKS[10] - C.RANKS[9], "test")
check(owns(gus, "miners_guild_3"), "D rank 10 unlocks the winged cloak")
local title, _, text = grug_achievements.row(gus, ach)
eq(title, "Miner's Guild III", "D the series' last title")
eq(text, "Reach Reputation Rank 10 with the Miner's Guild.", "D the condition's text")

------------------------------------------------------------------------------
-- E. Round 58 §2a and the consumables' payout.
------------------------------------------------------------------------------
local mason = {}
for _, entry in ipairs(grug_traders.profession_stock.mason or {}) do mason[entry.item] = true end
check(next(mason) ~= nil, "E the mason has a shelf")
check(not mason["default:cobble"], "E the mason sells no Cobblestone")
check(not mason["default:gravel"], "E the mason sells no Gravel")
check(mason["default:stonebrick"] and mason["default:clay_brick"], "E the mason keeps his bricks")
for kind, shelf in pairs(grug_traders.profession_stock) do
	for _, entry in ipairs(shelf) do
		check(not C.EXCHANGE_BY_ITEM[entry.item], "E shelf " .. kind .. " sells no exchanged item: " .. entry.item)
	end
end
for _, entry in ipairs(grug_traders.stock) do
	check(not C.EXCHANGE_BY_ITEM[entry.item], "E the core stock sells no exchanged item: " .. entry.item)
end
check(C.exchange_rate("default:cobble") ~= nil and C.exchange_rate("default:gravel") ~= nil,
	"E Cobblestone and Gravel are exchanged")
for _, row in ipairs(C.EXCHANGE) do eq(row.pending, nil, "E no pending row: " .. row.item) end

-- The payout: two stand-in registrations of consumables (lane CONSUME
-- registers the real ones), then the price module's own resolution.
for _, item in ipairs({"grug_guild:ore_sense_t1", "grug_guild:treasure_hunt_t6"}) do
	if not core.registered_items[item] then
		core.register_craftitem(item, {description = item})
	end
end
local ok, resolve_err = pcall(grug_traders.resolve_prices)
if check(ok, "E the prices resolve: " .. tostring(resolve_err)) then
	eq(grug_traders.sell_price("grug_guild:ore_sense_t1"), C.consumable("ore_sense", 1).sell_copper,
		"E Ore Sense I pays its sell_copper")
	eq(grug_traders.sell_price("grug_guild:treasure_hunt_t6"), C.consumable("treasure_hunt", 6).sell_copper,
		"E Treasure Hunt VI pays its sell_copper")
	local copper, lot = grug_traders.sell_offer(ItemStack("default:cobble 10"))
	check(copper == 1 and lot == 50, "E vendors still buy Cobblestone (1c per 50)")
	copper, lot = grug_traders.sell_offer(ItemStack("default:gravel 10"))
	check(copper == 1 and lot == 50, "E vendors still buy Gravel (1c per 50)")
end

if failures > 0 then
	error("R58 REP PORTABLE FAIL " .. failures .. " of " .. checks)
end
print("R58 REP PORTABLE PASS checks=" .. checks)
